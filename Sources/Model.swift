import Foundation
import simd

struct Atom {
    let serial: Int
    let name: String          // PDB atom name: "CA", "N", "C", "O", "CB", "OG1", "FE"
    let element: String       // Element symbol, uppercased: "C", "N", "O", "S", "FE"
    let chain: Character
    let resSeq: Int
    let resName: String       // "ALA", "GLY", "HOH"
    let position: SIMD3<Float>
    let isHetatm: Bool
}

struct SSSpan {
    enum Kind { case helix, sheet }
    let kind: Kind
    let chain: Character
    let startResSeq: Int
    let endResSeq: Int
}

struct ChainAnnotation {
    let id: Character
    let molecule: String?
    let residueCount: Int
}

struct PDBHeader {
    let classification: String?
    let title: String?
    let authors: [String]
    let method: String?
    let resolution: Float?
    let organisms: [String]
}

struct ParsedStructure {
    let id: String
    let header: PDBHeader
    let atoms: [Atom]
    let chains: [ChainAnnotation]
    let secondary: [SSSpan]
    let center: SIMD3<Float>
    let radius: Float

    func caAtoms(chain c: Character) -> [Atom] {
        atoms.filter { $0.chain == c && !$0.isHetatm && $0.name == "CA" }
             .sorted { $0.resSeq < $1.resSeq }
    }

    func ssKind(chain c: Character, resSeq r: Int) -> SSSpan.Kind? {
        for span in secondary where span.chain == c && r >= span.startResSeq && r <= span.endResSeq {
            return span.kind
        }
        return nil
    }
}
