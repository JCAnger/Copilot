import ActivityKit
import Foundation

// ⚠️ Ce fichier doit appartenir AUX DEUX cibles : l'app ET l'extension widget.

/// Les situations que le copilote sait signaler pendant un trajet.
enum CopiloteScenario: String, Codable, Hashable, CaseIterable {
    case pause     // aire de repos la plus proche
    case carburant // station la plus proche avec le prix du carburant choisi

    var symbol: String {
        switch self {
        case .pause:     return "cup.and.saucer.fill"
        case .carburant: return "fuelpump.fill"
        }
    }

    var label: String {
        switch self {
        case .pause:     return "Pause conseillée"
        case .carburant: return "Carburant"
        }
    }
}

/// Enseignes de stations-service reconnues. Sert à afficher un logo à la place du pictogramme.
enum Enseigne: String, Codable, Hashable, CaseIterable {
    case totalenergies, leclerc, carrefour, intermarche, auchan, esso, bp, shell
    case avia, eni, casino, systemeU, cora, netto

    var nom: String {
        switch self {
        case .totalenergies: return "TotalEnergies"
        case .leclerc:       return "E.Leclerc"
        case .carrefour:     return "Carrefour"
        case .intermarche:   return "Intermarché"
        case .auchan:        return "Auchan"
        case .esso:          return "Esso"
        case .bp:            return "BP"
        case .shell:         return "Shell"
        case .avia:          return "Avia"
        case .eni:           return "Eni"
        case .casino:        return "Casino"
        case .systemeU:      return "Système U"
        case .cora:          return "Cora"
        case .netto:         return "Netto"
        }
    }

    /// Initiales affichées sur la pastille quand aucun fichier logo n'est fourni.
    var initiales: String {
        switch self {
        case .totalenergies: return "TE"
        case .leclerc:       return "E.L"
        case .carrefour:     return "C"
        case .intermarche:   return "IM"
        case .auchan:        return "A"
        case .esso:          return "Esso"
        case .bp:            return "bp"
        case .shell:         return "S"
        case .avia:          return "AV"
        case .eni:           return "eni"
        case .casino:        return "CA"
        case .systemeU:      return "U"
        case .cora:          return "CO"
        case .netto:         return "N"
        }
    }

    /// Couleur dominante de la marque (rouge, vert, bleu entre 0 et 1).
    var couleur: (rouge: Double, vert: Double, bleu: Double) {
        switch self {
        case .totalenergies: return (0.90, 0.10, 0.15)
        case .leclerc:       return (0.0, 0.35, 0.70)
        case .carrefour:     return (0.0, 0.30, 0.65)
        case .intermarche:   return (0.85, 0.10, 0.15)
        case .auchan:        return (0.85, 0.10, 0.15)
        case .esso:          return (0.0, 0.25, 0.60)
        case .bp:            return (0.0, 0.55, 0.25)
        case .shell:         return (0.95, 0.70, 0.0)
        case .avia:          return (0.85, 0.10, 0.15)
        case .eni:           return (0.95, 0.75, 0.0)
        case .casino:        return (0.0, 0.55, 0.30)
        case .systemeU:      return (0.85, 0.10, 0.20)
        case .cora:          return (0.0, 0.35, 0.65)
        case .netto:         return (0.95, 0.80, 0.0)
        }
    }

    /// Mots à repérer dans le nom du lieu. Les mots de 3 lettres ou moins doivent correspondre exactement.
    private var motsCles: [String] {
        switch self {
        case .totalenergies: return ["total", "totalenergies"]
        case .leclerc:       return ["leclerc"]
        case .carrefour:     return ["carrefour"]
        case .intermarche:   return ["intermarche"]
        case .auchan:        return ["auchan"]
        case .esso:          return ["esso"]
        case .bp:            return ["bp"]
        case .shell:         return ["shell"]
        case .avia:          return ["avia"]
        case .eni:           return ["eni", "agip"]
        case .casino:        return ["casino"]
        case .systemeU:      return ["systeme u", "super u", "hyper u", "u express", "marche u"]
        case .cora:          return ["cora"]
        case .netto:         return ["netto"]
        }
    }

    /// Retrouve l'enseigne à partir d'un nom de lieu (ex. « TotalEnergies Coupvray »).
    static func reconnaitre(_ texte: String) -> Enseigne? {
        let propre = texte.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        let mots = Set(propre.split { !$0.isLetter }.map(String.init))
        return allCases.first { enseigne in
            enseigne.motsCles.contains { cle in
                cle.count <= 3 ? mots.contains(cle) : propre.contains(cle)
            }
        }
    }
}

struct CopiloteAttributes: ActivityAttributes {

    /// Contenu qui change pendant le trajet (envoyé à chaque mise à jour).
    struct ContentState: Codable, Hashable {
        var scenario: CopiloteScenario
        /// Information principale, très courte : lisible d'un coup d'œil.
        var titre: String
        /// Seconde ligne facultative.
        var detail: String
        /// Distance ou délai, affiché en valeur forte (ex. "12 km", "15 min").
        var valeur: String
        /// Enseigne de la station, quand elle est reconnue.
        var enseigne: Enseigne? = nil
    }

    /// Données fixes pour toute la durée de l'activité.
    var nomTrajet: String
}
