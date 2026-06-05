import Foundation
import simd

enum PDBParser {

    static func parse(_ text: String, id: String) -> ParsedStructure {
        var atoms: [Atom] = []
        var chainOrder: [Character] = []
        var chainSeen: Set<Character> = []
        var chainResidues: [Character: Set<Int>] = [:]
        var minP = SIMD3<Float>(repeating:  .infinity)
        var maxP = SIMD3<Float>(repeating: -.infinity)
        var inFirstModel = true

        var classification: String?
        var titleBuf = ""
        var compndBuf = ""
        var sourceBuf = ""
        var authorBuf = ""
        var methodBuf = ""
        var resolution: Float?
        var ssSpans: [SSSpan] = []

        text.enumerateLines { line, _ in
            // ATOM/HETATM dominate file size — check first.
            if inFirstModel, (line.hasPrefix("ATOM") || line.hasPrefix("HETATM")), line.count >= 54 {
                let isHet = line.hasPrefix("HETATM")
                let chars = Array(line)
                // PDB v3.3 fixed columns (1-indexed → 0-indexed -1):
                //  7-11 serial → 6..<11    13-16 atom name → 12..<16
                // 18-20 resName → 17..<20  22 chain → 21
                // 23-26 resSeq → 22..<26   31-38 x → 30..<38   39-46 y → 38..<46   47-54 z → 46..<54
                // 77-78 element → 76..<78
                let serial  = Int(String(chars[6..<11]).trimmingCharacters(in: .whitespaces)) ?? 0
                let name    = String(chars[12..<16]).trimmingCharacters(in: .whitespaces)
                let resName = String(chars[17..<20]).trimmingCharacters(in: .whitespaces)
                let chain   = chars[21]
                let resSeq  = Int(String(chars[22..<26]).trimmingCharacters(in: .whitespaces)) ?? 0
                guard let x = Float(String(chars[30..<38]).trimmingCharacters(in: .whitespaces)),
                      let y = Float(String(chars[38..<46]).trimmingCharacters(in: .whitespaces)),
                      let z = Float(String(chars[46..<54]).trimmingCharacters(in: .whitespaces)) else { return }

                let element: String
                if chars.count >= 78 {
                    let e = String(chars[76..<78]).trimmingCharacters(in: .whitespaces).uppercased()
                    element = e.isEmpty ? inferElement(fromName: name) : e
                } else {
                    element = inferElement(fromName: name)
                }

                let pos = SIMD3<Float>(x, y, z)
                atoms.append(Atom(
                    serial: serial, name: name, element: element,
                    chain: chain, resSeq: resSeq, resName: resName,
                    position: pos, isHetatm: isHet
                ))
                if !isHet {
                    if !chainSeen.contains(chain) { chainSeen.insert(chain); chainOrder.append(chain) }
                    chainResidues[chain, default: []].insert(resSeq)
                }
                minP = simd_min(minP, pos)
                maxP = simd_max(maxP, pos)
                return
            }

            if line.hasPrefix("ENDMDL") { inFirstModel = false; return }

            if line.hasPrefix("HEADER") {
                let chars = Array(line)
                if chars.count >= 11 {
                    let end = min(50, chars.count)
                    let cls = String(chars[10..<end]).trimmingCharacters(in: .whitespaces)
                    if !cls.isEmpty { classification = cls }
                }
                return
            }
            if line.hasPrefix("TITLE")  { titleBuf  += " " + bodyAfterContinuation(line); return }
            if line.hasPrefix("COMPND") { compndBuf += " " + bodyAfterContinuation(line); return }
            if line.hasPrefix("SOURCE") { sourceBuf += " " + bodyAfterContinuation(line); return }
            if line.hasPrefix("AUTHOR") { authorBuf += " " + bodyAfterContinuation(line); return }
            if line.hasPrefix("EXPDTA") { methodBuf += " " + bodyAfterContinuation(line); return }

            if line.hasPrefix("REMARK   2") && line.contains("RESOLUTION.") {
                // "REMARK   2 RESOLUTION.    1.70 ANGSTROMS."
                if let r = line.range(of: "RESOLUTION.") {
                    for tok in line[r.upperBound...].split(whereSeparator: { $0 == " " || $0 == "\t" }) {
                        if let v = Float(tok) { resolution = v; break }
                    }
                }
                return
            }

            if line.hasPrefix("HELIX"), line.count >= 38 {
                // 20 initChainID, 22-25 initSeqNum, 32 endChainID, 34-37 endSeqNum
                let chars = Array(line)
                let chain = chars[19]
                let start = Int(String(chars[21..<25]).trimmingCharacters(in: .whitespaces)) ?? 0
                let end   = Int(String(chars[33..<37]).trimmingCharacters(in: .whitespaces)) ?? 0
                if start > 0, end > 0 {
                    ssSpans.append(SSSpan(kind: .helix, chain: chain, startResSeq: start, endResSeq: end))
                }
                return
            }
            if line.hasPrefix("SHEET"), line.count >= 38 {
                // 22 initChainID, 23-26 initSeqNum, 33 endChainID, 34-37 endSeqNum
                let chars = Array(line)
                let chain = chars[21]
                let start = Int(String(chars[22..<26]).trimmingCharacters(in: .whitespaces)) ?? 0
                let end   = Int(String(chars[33..<37]).trimmingCharacters(in: .whitespaces)) ?? 0
                if start > 0, end > 0 {
                    ssSpans.append(SSSpan(kind: .sheet, chain: chain, startResSeq: start, endResSeq: end))
                }
            }
        }

        let center: SIMD3<Float>
        let radius: Float
        if minP.x.isFinite {
            center = (minP + maxP) / 2
            radius = max(simd_length(maxP - minP) / 2, 1)
        } else {
            center = .zero
            radius = 1
        }

        let chainToMolecule = parseCompndMoleculeByChain(compndBuf)
        let chains = chainOrder.map { c in
            ChainAnnotation(
                id: c,
                molecule: chainToMolecule[c],
                residueCount: chainResidues[c]?.count ?? 0
            )
        }

        let header = PDBHeader(
            classification: nonEmpty(classification),
            title:    nonEmpty(collapse(titleBuf)),
            authors:  parseAuthors(authorBuf),
            method:   nonEmpty(collapse(methodBuf)),
            resolution: resolution,
            organisms: extractTokens(sourceBuf, key: "ORGANISM_SCIENTIFIC")
        )

        return ParsedStructure(
            id: id, header: header, atoms: atoms, chains: chains,
            secondary: ssSpans, center: center, radius: radius
        )
    }

    private static func bodyAfterContinuation(_ line: String) -> String {
        let chars = Array(line)
        guard chars.count > 10 else { return "" }
        return String(chars[10...]).trimmingCharacters(in: .whitespaces)
    }

    private static func collapse(_ s: String) -> String {
        s.split(separator: " ", omittingEmptySubsequences: true).joined(separator: " ")
    }

    private static func nonEmpty(_ s: String?) -> String? {
        guard let s = s?.trimmingCharacters(in: .whitespaces), !s.isEmpty else { return nil }
        return s
    }

    private static func parseAuthors(_ raw: String) -> [String] {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }
        return trimmed
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// COMPND/SOURCE records carry KEY: VALUE; tokens spread across continuation
    /// lines. Pull out values for a specific key, deduped, preserving order.
    private static func extractTokens(_ raw: String, key: String) -> [String] {
        var out: [String] = []
        for token in raw.split(separator: ";") {
            let t = token.trimmingCharacters(in: .whitespaces)
            guard let colon = t.firstIndex(of: ":") else { continue }
            let k = t[..<colon].trimmingCharacters(in: .whitespaces).uppercased()
            guard k == key else { continue }
            let v = t[t.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            if !v.isEmpty { out.append(v) }
        }
        var seen = Set<String>()
        return out.filter { seen.insert($0).inserted }
    }

    /// COMPND blocks chunk by MOL_ID. Each block has one MOLECULE and one or more
    /// CHAIN entries. Walk tokens sequentially, attributing the latest MOLECULE
    /// to each subsequent CHAIN.
    private static func parseCompndMoleculeByChain(_ raw: String) -> [Character: String] {
        var map: [Character: String] = [:]
        var currentMolecule: String?
        for token in raw.split(separator: ";") {
            let t = token.trimmingCharacters(in: .whitespaces)
            guard let colon = t.firstIndex(of: ":") else { continue }
            let key = t[..<colon].trimmingCharacters(in: .whitespaces).uppercased()
            let value = t[t.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            switch key {
            case "MOL_ID":   currentMolecule = nil
            case "MOLECULE": currentMolecule = value
            case "CHAIN":
                guard let mol = currentMolecule else { continue }
                for c in value.split(separator: ",") {
                    let s = c.trimmingCharacters(in: .whitespaces)
                    if let first = s.first { map[first] = mol }
                }
            default: break
            }
        }
        return map
    }

    /// Element inference fallback. PDB v3 puts the element symbol in cols 77-78;
    /// older files don't. For amino acid atoms ("CA", "CB", "OG1") the element is
    /// the first letter. Two-letter elements ("FE", "MG", "ZN") usually come from
    /// HETATM and have the element column populated.
    private static func inferElement(fromName name: String) -> String {
        let stripped = name.trimmingCharacters(in: .whitespaces)
        guard let first = stripped.first(where: { $0.isLetter }) else { return "C" }
        return String(first).uppercased()
    }
}
