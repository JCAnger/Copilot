import CoreLocation
import Foundation
import MapKit

/// Aire de repos ou de services proche de la position courante.
struct AireDeRepos {
    let nom: String
    let distanceMetres: CLLocationDistance
}

enum AireServiceErreur: Error {
    case aucuneAire
}

/// Trouve l'aire de repos la plus proche grâce à la recherche de lieux d'Apple Maps.
enum AireService {
    static func plusProche(de position: CLLocation, rayonMetres: CLLocationDistance = 50_000) async throws -> AireDeRepos {
        let requete = MKLocalSearch.Request()
        requete.naturalLanguageQuery = "aire de repos"
        requete.region = MKCoordinateRegion(center: position.coordinate,
                                            latitudinalMeters: rayonMetres * 2,
                                            longitudinalMeters: rayonMetres * 2)

        let reponse = try await MKLocalSearch(request: requete).start()
        let proches = reponse.mapItems
            .compactMap { item -> AireDeRepos? in
                guard let lieu = item.placemark.location else { return nil }
                let distance = position.distance(from: lieu)
                guard distance <= rayonMetres else { return nil }
                return AireDeRepos(nom: item.name ?? "Aire de repos", distanceMetres: distance)
            }
            .sorted { $0.distanceMetres < $1.distanceMetres }

        guard let aire = proches.first else { throw AireServiceErreur.aucuneAire }
        return aire
    }
}

extension CopiloteAttributes.ContentState {
    /// Convertit une aire réelle en contenu de Live Activity.
    init(aire: AireDeRepos) {
        let distance = Measurement(value: aire.distanceMetres, unit: UnitLength.meters)
            .formatted(.measurement(width: .abbreviated, usage: .road).locale(Locale(identifier: "fr_FR")))
        self.init(scenario: .pause,
                  titre: aire.nom,
                  detail: "Pause conseillée",
                  valeur: distance)
    }
}
