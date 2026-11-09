import ActivityKit
import CoreLocation
import Foundation
import Observation
import UserNotifications

/// Démarre, met à jour et arrête la Live Activity « Copilote ».
/// Les informations affichées sont réelles : station la plus proche (carburant choisi dans les réglages)
/// et aire de repos la plus proche. Quand plusieurs informations sont activées, elles alternent.
@MainActor
@Observable
final class CopiloteManager {
    static let shared = CopiloteManager()

    private(set) var estActif = false
    private(set) var scenarioCourant: CopiloteAttributes.ContentState?
    /// Raison pour laquelle le copilote n'a pas pu démarrer (affichée sur l'accueil).
    private(set) var messageErreur: String?

    private var activity: Activity<CopiloteAttributes>?
    private var tacheActualisation: Task<Void, Never>?
    private var tacheAutorisation: Task<Void, Never>?
    /// Compteur qui fait alterner les informations actives.
    private var rang = 0
    /// Évite deux démarrages simultanés (ex. bouton + Siri), qui créeraient deux activités.
    private var demarrageEnCours = false

    // Suivi de position en arrière-plan : garde l'app active pendant le trajet
    // pour que l'actualisation automatique continue écran verrouillé et sur CarPlay.
    private var sessionArrierePlan: CLBackgroundActivitySession?
    private var tacheLocalisation: Task<Void, Never>?
    private var dernierePosition: CLLocation?

    private init() {
        // Récupère une activité déjà en cours (ex. lancée par Siri pendant que l'app était fermée)
        // et ferme les éventuels doublons : une seule activité « Copilote » à la fois.
        let existantes = Activity<CopiloteAttributes>.activities
        activity = existantes.first
        for doublon in existantes.dropFirst() {
            Task { await doublon.end(nil, dismissalPolicy: .immediate) }
        }
        estActif = activity != nil
        scenarioCourant = activity?.content.state
        surveillerAutorisation()
        if activity != nil {
            demarrerSuiviPosition()
            lancerActualisationSiBesoin()
        }
    }

    // MARK: - Diagnostic : réglage « Activités en temps réel »

    /// Écrit dans la console chaque changement du réglage, avec l'heure.
    /// Sert à comprendre pourquoi il se décoche (ex. à la reconnexion de CarPlay).
    private func surveillerAutorisation() {
        tacheAutorisation = Task {
            let info = ActivityAuthorizationInfo()
            print("ℹ️ Live Activities au lancement : \(info.areActivitiesEnabled ? "activées" : "désactivées")")
            for await actif in info.activityEnablementUpdates {
                let heure = Date().formatted(date: .omitted, time: .standard)
                print("ℹ️ \(heure) Live Activities : \(actif ? "activées" : "désactivées")")
            }
        }
    }

    // MARK: - Notifications (dont CarPlay)

    private(set) var etatNotifications = "Non vérifié"

    /// Demande l'autorisation au lancement de l'app, option CarPlay incluse.
    func demanderNotifications() async {
        let centre = UNUserNotificationCenter.current()
        do {
            _ = try await centre.requestAuthorization(options: [.alert, .sound, .badge, .carPlay])
        } catch {
            etatNotifications = "Erreur : \(error.localizedDescription)"
            return
        }
        let reglages = await centre.notificationSettings()
        let auto: String
        switch reglages.authorizationStatus {
        case .authorized:    auto = "autorisées"
        case .denied:        auto = "refusées"
        case .notDetermined: auto = "non demandées"
        case .provisional:   auto = "provisoires"
        case .ephemeral:     auto = "éphémères"
        @unknown default:    auto = "inconnu"
        }
        let carplay = reglages.carPlaySetting == .enabled ? "CarPlay activé" : "CarPlay désactivé"
        etatNotifications = "Notifications \(auto) · \(carplay)"
    }

    var liveActivitiesAutorisees: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    // MARK: - Cycle de vie

    /// Démarre la Live Activity avec la première information réelle disponible.
    /// Renvoie `false` (et renseigne `messageErreur`) si rien ne peut être affiché.
    @discardableResult
    func demarrer() async -> Bool {
        messageErreur = nil
        guard liveActivitiesAutorisees else {
            messageErreur = "Live Activities désactivées dans Réglages."
            return false
        }
        guard !scenariosActifs.isEmpty else {
            messageErreur = "Active au moins une information dans les réglages du copilote."
            return false
        }

        guard !demarrageEnCours else { return estActif }
        demarrageEnCours = true
        defer { demarrageEnCours = false }

        demarrerSuiviPosition()

        // Une seule activité « Copilote » à la fois : si une activité tourne déjà
        // (ex. Siri relancé à la connexion de CarPlay), on la réutilise au lieu d'en créer une autre.
        if let existante = activity ?? Activity<CopiloteAttributes>.activities.first {
            activity = existante
            fermerDoublons()
            estActif = true
            await scenarioSuivant()
            lancerActualisationSiBesoin()
            return true
        }

        rang = 0
        guard let etat = await prochainEtat() else {
            messageErreur = "Aucune information disponible : vérifie la localisation, le réseau et le rayon de recherche."
            arreterSuiviPosition()
            return false
        }
        do {
            activity = try Activity.request(
                attributes: CopiloteAttributes(nomTrajet: "Trajet en cours"),
                content: ActivityContent(state: etat, staleDate: nil, relevanceScore: 100),
                pushType: nil // en production : .token pour les mises à jour serveur
            )
            fermerDoublons()
            estActif = true
            scenarioCourant = etat
            lancerActualisationSiBesoin()
            return true
        } catch {
            print("❌ Impossible de démarrer la Live Activity : \(error)")
            messageErreur = "Impossible de démarrer la Live Activity."
            arreterSuiviPosition()
            return false
        }
    }

    /// Passe à l'information suivante (ou actualise l'unique information activée).
    /// Si rien de nouveau n'est disponible, l'affichage actuel est conservé.
    func scenarioSuivant() async {
        guard let activity else { return }
        guard let etat = await prochainEtat() else { return }
        await activity.update(ActivityContent(state: etat, staleDate: nil, relevanceScore: 100))
        scenarioCourant = etat
    }

    func arreter() async {
        tacheActualisation?.cancel()
        tacheActualisation = nil
        arreterSuiviPosition()
        for a in Activity<CopiloteAttributes>.activities {
            await a.end(nil, dismissalPolicy: .immediate)
        }
        activity = nil
        estActif = false
        scenarioCourant = nil
    }

    /// Ferme toute activité « Copilote » autre que celle suivie par le gestionnaire.
    private func fermerDoublons() {
        for a in Activity<CopiloteAttributes>.activities where a.id != activity?.id {
            Task { await a.end(nil, dismissalPolicy: .immediate) }
        }
    }

    // MARK: - Position en arrière-plan

    private func demarrerSuiviPosition() {
        guard tacheLocalisation == nil else { return }
        // La session affiche l'indicateur de localisation et autorise l'app (« Lorsque l'app est active »)
        // à continuer de recevoir des positions — et donc d'actualiser — en arrière-plan.
        sessionArrierePlan = CLBackgroundActivitySession()
        tacheLocalisation = Task { [weak self] in
            do {
                for try await maj in CLLocationUpdate.liveUpdates(.automotiveNavigation) {
                    guard !Task.isCancelled else { return }
                    if let position = maj.location { self?.dernierePosition = position }
                }
            } catch {
                print("⚠️ Suivi de position interrompu : \(error)")
            }
        }
    }

    private func arreterSuiviPosition() {
        tacheLocalisation?.cancel()
        tacheLocalisation = nil
        sessionArrierePlan?.invalidate()
        sessionArrierePlan = nil
        dernierePosition = nil
    }

    /// Dernière position du suivi si elle est récente, sinon une nouvelle mesure.
    private func position() async throws -> CLLocation {
        if let dernierePosition, dernierePosition.timestamp.timeIntervalSinceNow > -120 {
            return dernierePosition
        }
        return try await StationService.positionCourante()
    }

    // MARK: - Données réelles

    private var scenariosActifs: [CopiloteScenario] {
        var liste: [CopiloteScenario] = []
        if Reglages.afficherCarburant { liste.append(.carburant) }
        if Reglages.afficherPause { liste.append(.pause) }
        return liste
    }

    /// Première information disponible, en alternant entre les informations activées.
    private func prochainEtat() async -> CopiloteAttributes.ContentState? {
        let actifs = scenariosActifs
        guard !actifs.isEmpty else { return nil }
        for _ in actifs {
            let scenario = actifs[rang % actifs.count]
            rang += 1
            if let etat = await etat(pour: scenario) { return etat }
        }
        return nil
    }

    private func etat(pour scenario: CopiloteScenario) async -> CopiloteAttributes.ContentState? {
        do {
            let position = try await self.position()
            switch scenario {
            case .carburant:
                let station = try await StationService.plusProche(de: position,
                                                                  carburant: Reglages.carburant,
                                                                  rayonKm: Reglages.rayonStationKm)
                return CopiloteAttributes.ContentState(station: station)
            case .pause:
                let aire = try await AireService.plusProche(de: position,
                                                            rayonMetres: Double(Reglages.rayonAireKm) * 1000)
                return CopiloteAttributes.ContentState(aire: aire)
            }
        } catch {
            print("⚠️ Information « \(scenario.label) » indisponible : \(error)")
            return nil
        }
    }

    // MARK: - Actualisation automatique

    /// (Re)lance la minuterie selon les réglages ; à appeler après chaque changement de réglage
    /// pour que la nouvelle fréquence s'applique tout de suite.
    func lancerActualisationSiBesoin() {
        tacheActualisation?.cancel()
        tacheActualisation = nil
        guard Reglages.actualisationAuto, activity != nil else { return }
        tacheActualisation = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Reglages.intervalleSecondes))
                guard !Task.isCancelled else { return }
                await self?.scenarioSuivant()
            }
        }
    }
}
