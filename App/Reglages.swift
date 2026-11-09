import Foundation

/// Carburants proposés par l'open data. `champ` est le préfixe des colonnes du jeu de données.
enum TypeCarburant: String, CaseIterable, Identifiable {
    case gazole, sp95, sp98, e10, e85, gplc

    var id: String { rawValue }

    var nom: String {
        switch self {
        case .gazole: return "Gazole"
        case .sp95:   return "SP95"
        case .sp98:   return "SP98"
        case .e10:    return "SP95-E10"
        case .e85:    return "E85"
        case .gplc:   return "GPLc"
        }
    }

    /// Colonne du prix dans le jeu de données (ex. `gazole_prix`).
    var champPrix: String { "\(rawValue)_prix" }
}

/// Réglages de l'utilisateur, stockés dans `UserDefaults`.
/// L'écran de réglages les lit et les écrit avec `@AppStorage` et les clés ci-dessous.
enum Reglages {
    enum Cle {
        static let carburant = "reglages.carburant"
        static let afficherCarburant = "reglages.afficherCarburant"
        static let rayonStationKm = "reglages.rayonStationKm"
        static let afficherPause = "reglages.afficherPause"
        static let rayonAireKm = "reglages.rayonAireKm"
        static let intervalleSecondes = "reglages.intervalleSecondes"
        static let actualisationAuto = "reglages.actualisationAuto"
    }

    enum Defaut {
        static let carburant = TypeCarburant.gazole.rawValue
        static let afficherCarburant = true
        static let rayonStationKm = 20
        static let afficherPause = true
        static let rayonAireKm = 50
        static let intervalleSecondes = 30
        static let actualisationAuto = true
    }

    private static var defaults: UserDefaults { .standard }

    static var carburant: TypeCarburant {
        TypeCarburant(rawValue: defaults.string(forKey: Cle.carburant) ?? Defaut.carburant) ?? .gazole
    }
    static var afficherCarburant: Bool {
        defaults.object(forKey: Cle.afficherCarburant) as? Bool ?? Defaut.afficherCarburant
    }
    static var rayonStationKm: Int {
        defaults.object(forKey: Cle.rayonStationKm) as? Int ?? Defaut.rayonStationKm
    }
    static var afficherPause: Bool {
        defaults.object(forKey: Cle.afficherPause) as? Bool ?? Defaut.afficherPause
    }
    static var rayonAireKm: Int {
        defaults.object(forKey: Cle.rayonAireKm) as? Int ?? Defaut.rayonAireKm
    }
    static var intervalleSecondes: Int {
        defaults.object(forKey: Cle.intervalleSecondes) as? Int ?? Defaut.intervalleSecondes
    }
    static var actualisationAuto: Bool {
        defaults.object(forKey: Cle.actualisationAuto) as? Bool ?? Defaut.actualisationAuto
    }
}
