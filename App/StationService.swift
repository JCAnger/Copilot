import CoreLocation
import Foundation
import MapKit

/// Station-service avec le prix du carburant demandé, telle que renvoyée par l'open data du gouvernement.
struct StationCarburant {
    let carburant: TypeCarburant
    let adresse: String
    let ville: String
    let prix: Double
    let coordonnee: CLLocationCoordinate2D
    let distanceMetres: CLLocationDistance
    var enseigne: Enseigne?
}

enum StationServiceErreur: Error {
    case localisationRefusee
    case aucuneStation
    case reponseInvalide
}

/// Trouve la station la plus proche proposant le carburant choisi.
/// Source : « Prix des carburants en France – flux instantané » (data.economie.gouv.fr).
enum StationService {
    private static let url = URL(string: "https://data.economie.gouv.fr/api/explore/v2.1/catalog/datasets/prix-des-carburants-en-france-flux-instantane-v2/records")!

    /// Position courante, en demandant l'autorisation si nécessaire.
    @MainActor
    static func positionCourante() async throws -> CLLocation {
        try await LocalisationUnique().position()
    }

    static func plusProche(de position: CLLocation, carburant: TypeCarburant, rayonKm: Int) async throws -> StationCarburant {
        let lat = position.coordinate.latitude
        let lon = position.coordinate.longitude
        let point = "geom'POINT(\(lon) \(lat))'"
        let champ = carburant.champPrix

        var composants = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        composants.queryItems = [
            URLQueryItem(name: "where", value: "within_distance(geom, \(point), \(rayonKm)km) AND \(champ) is not null"),
            URLQueryItem(name: "order_by", value: "distance(geom, \(point))"),
            URLQueryItem(name: "limit", value: "1"),
            URLQueryItem(name: "select", value: "adresse,ville,\(champ),geom")
        ]

        let (donnees, _) = try await URLSession.shared.data(from: composants.url!)
        guard let json = try JSONSerialization.jsonObject(with: donnees) as? [String: Any],
              let resultats = json["results"] as? [[String: Any]] else {
            throw StationServiceErreur.reponseInvalide
        }
        guard let r = resultats.first else { throw StationServiceErreur.aucuneStation }
        guard let adresse = r["adresse"] as? String,
              let ville = r["ville"] as? String,
              let prix = r[champ] as? Double,
              let geom = r["geom"] as? [String: Double],
              let sLat = geom["lat"], let sLon = geom["lon"] else {
            throw StationServiceErreur.reponseInvalide
        }

        let coordonnee = CLLocationCoordinate2D(latitude: sLat, longitude: sLon)
        let distance = position.distance(from: CLLocation(latitude: sLat, longitude: sLon))
        let enseigne = await enseigne(pres: coordonnee)
        return StationCarburant(carburant: carburant, adresse: adresse, ville: ville, prix: prix,
                                coordonnee: coordonnee, distanceMetres: distance, enseigne: enseigne)
    }

    /// Le jeu de données ne contient pas l'enseigne : on la déduit du lieu « station-service »
    /// le plus proche dans Apple Maps (à moins de 150 m de la station).
    private static func enseigne(pres coordonnee: CLLocationCoordinate2D) async -> Enseigne? {
        let centre = CLLocation(latitude: coordonnee.latitude, longitude: coordonnee.longitude)

        // 1. Recherche par catégorie « station-service » : plus fiable qu'un texte libre.
        let parCategorie = MKLocalPointsOfInterestRequest(center: coordonnee, radius: 300)
        parCategorie.pointOfInterestFilter = MKPointOfInterestFilter(including: [.gasStation])
        var lieux = (try? await MKLocalSearch(request: parCategorie).start())?.mapItems ?? []

        // 2. Secours : recherche textuelle autour de la station.
        if lieux.isEmpty {
            let parTexte = MKLocalSearch.Request()
            parTexte.naturalLanguageQuery = "station-service"
            parTexte.region = MKCoordinateRegion(center: coordonnee, latitudinalMeters: 600, longitudinalMeters: 600)
            lieux = (try? await MKLocalSearch(request: parTexte).start())?.mapItems ?? []
        }

        return lieux
            .compactMap { item -> (distance: CLLocationDistance, nom: String)? in
                guard let lieu = item.placemark.location, let nom = item.name else { return nil }
                let distance = centre.distance(from: lieu)
                return distance <= 250 ? (distance, nom) : nil
            }
            .sorted { $0.distance < $1.distance }
            .lazy
            .compactMap { Enseigne.reconnaitre($0.nom) }
            .first
    }
}

/// Obtient une position unique via `CLLocationManager`, en demandant l'autorisation si besoin.
@MainActor
private final class LocalisationUnique: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation, Error>?

    func position() async throws -> CLLocation {
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            switch manager.authorizationStatus {
            case .notDetermined:
                manager.requestWhenInUseAuthorization()
            case .denied, .restricted:
                terminer(.failure(StationServiceErreur.localisationRefusee))
            default:
                manager.requestLocation()
            }
        }
    }

    private func terminer(_ resultat: Result<CLLocation, Error>) {
        continuation?.resume(with: resultat)
        continuation = nil
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        MainActor.assumeIsolated {
            switch manager.authorizationStatus {
            case .denied, .restricted: terminer(.failure(StationServiceErreur.localisationRefusee))
            case .authorizedAlways, .authorizedWhenInUse: manager.requestLocation()
            default: break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let derniere = locations.last else { return }
        MainActor.assumeIsolated { terminer(.success(derniere)) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        MainActor.assumeIsolated { terminer(.failure(error)) }
    }
}

extension CopiloteAttributes.ContentState {
    /// Convertit une station réelle en contenu de Live Activity.
    init(station: StationCarburant) {
        let fr = Locale(identifier: "fr_FR")
        let prix = station.prix.formatted(.number.precision(.fractionLength(3)).locale(fr))
        let distance = Measurement(value: station.distanceMetres, unit: UnitLength.meters)
            .formatted(.measurement(width: .abbreviated, usage: .road).locale(fr))
        self.init(scenario: .carburant,
                  titre: station.enseigne?.nom ?? "Station la plus proche",
                  detail: "\(station.carburant.nom) \(prix) € · \(station.ville)",
                  valeur: distance,
                  enseigne: station.enseigne)
    }
}
