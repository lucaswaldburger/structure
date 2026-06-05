import Foundation

final class PDBFetcher {

    enum FetchError: Error {
        case noEntryList
        case noLocalStructures
        case badStatus(Int)
        case emptyBody
    }

    private let session: URLSession
    private let cacheDir: URL
    private var ids: [String] = []
    private let bundle: Bundle

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
        self.bundle = Bundle(for: PDBFetcher.self)

        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.cacheDir = appSupport.appendingPathComponent("PDBStructure/cache", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)

        self.ids = loadIDs()
    }

    private func loadIDs() -> [String] {
        guard let url = bundle.url(forResource: "pdb_entry_type", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            NSLog("PDBStructure: pdb_entry_type.txt missing from bundle")
            return []
        }
        var out: [String] = []
        out.reserveCapacity(250_000)
        text.enumerateLines { line, _ in
            let cols = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard cols.count >= 2 else { return }
            let kind = cols[1]
            guard kind == "prot" || kind == "prot-nuc" else { return }
            let id = String(cols[0]).lowercased()
            guard id.count == 4 else { return }
            out.append(id)
        }
        return out
    }

    func fetchRandom(completion: @escaping (Result<ParsedStructure, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            // Local-only mode → only use bundled PDBs.
            if Defaults.onlyLocal {
                if let parsed = self.randomBundled() { completion(.success(parsed)); return }
                completion(.failure(FetchError.noLocalStructures)); return
            }

            // Internet disabled but not local-only → still prefer bundled, then cache.
            if !Defaults.enableInternet {
                if let parsed = self.randomBundled() { completion(.success(parsed)); return }
                if let parsed = self.randomCached()  { completion(.success(parsed)); return }
                completion(.failure(FetchError.noLocalStructures)); return
            }

            // Online: random ID from master list, with bundled fallback on failure.
            guard let id = self.ids.randomElement() else {
                if let parsed = self.randomBundled() { completion(.success(parsed)); return }
                completion(.failure(FetchError.noEntryList)); return
            }

            let cached = self.cacheDir.appendingPathComponent("\(id).pdb")
            if let text = try? String(contentsOf: cached, encoding: .utf8), !text.isEmpty {
                completion(.success(PDBParser.parse(text, id: id))); return
            }

            let url = URL(string: "https://files.rcsb.org/download/\(id.uppercased()).pdb")!
            self.session.dataTask(with: url) { data, response, error in
                DispatchQueue.global(qos: .userInitiated).async {
                    if let error {
                        NSLog("PDBStructure: download error for \(id): \(error.localizedDescription)")
                        if let parsed = self.randomBundled() { completion(.success(parsed)); return }
                        completion(.failure(error)); return
                    }
                    let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                    guard (200..<300).contains(status) else {
                        if let parsed = self.randomBundled() { completion(.success(parsed)); return }
                        completion(.failure(FetchError.badStatus(status))); return
                    }
                    guard let data, let text = String(data: data, encoding: .utf8), !text.isEmpty else {
                        if let parsed = self.randomBundled() { completion(.success(parsed)); return }
                        completion(.failure(FetchError.emptyBody)); return
                    }
                    try? data.write(to: cached, options: .atomic)
                    self.evictIfNeeded()
                    completion(.success(PDBParser.parse(text, id: id)))
                }
            }.resume()
        }
    }

    private func randomBundled() -> ParsedStructure? {
        let urls = bundle.urls(forResourcesWithExtension: "pdb", subdirectory: "PDB") ?? []
        guard let url = urls.randomElement(),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let id = url.deletingPathExtension().lastPathComponent
        return PDBParser.parse(text, id: id)
    }

    private func randomCached() -> ParsedStructure? {
        guard let files = try? FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil),
              let url = files.filter({ $0.pathExtension.lowercased() == "pdb" }).randomElement(),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let id = url.deletingPathExtension().lastPathComponent
        return PDBParser.parse(text, id: id)
    }

    private func evictIfNeeded() {
        let max = Defaults.cacheSize
        let keys: [URLResourceKey] = [.contentAccessDateKey]
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: cacheDir, includingPropertiesForKeys: keys
        ), files.count > max else { return }

        let sorted = files.sorted { a, b in
            let da = (try? a.resourceValues(forKeys: Set(keys)).contentAccessDate) ?? .distantPast
            let db = (try? b.resourceValues(forKeys: Set(keys)).contentAccessDate) ?? .distantPast
            return da < db
        }
        for url in sorted.prefix(files.count - max) {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
