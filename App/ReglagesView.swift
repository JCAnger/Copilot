import SwiftUI

/// Réglages du copilote : carburant suivi, informations affichées, rayons de recherche, fréquence.
struct ReglagesView: View {
    @AppStorage(Reglages.Cle.carburant) private var carburant = Reglages.Defaut.carburant
    @AppStorage(Reglages.Cle.afficherCarburant) private var afficherCarburant = Reglages.Defaut.afficherCarburant
    @AppStorage(Reglages.Cle.rayonStationKm) private var rayonStationKm = Reglages.Defaut.rayonStationKm
    @AppStorage(Reglages.Cle.afficherPause) private var afficherPause = Reglages.Defaut.afficherPause
    @AppStorage(Reglages.Cle.rayonAireKm) private var rayonAireKm = Reglages.Defaut.rayonAireKm
    @AppStorage(Reglages.Cle.intervalleSecondes) private var intervalleSecondes = Reglages.Defaut.intervalleSecondes
    @AppStorage(Reglages.Cle.actualisationAuto) private var actualisationAuto = Reglages.Defaut.actualisationAuto

    var body: some View {
        Form {
            Section {
                Toggle("Station-service", isOn: $afficherCarburant)
                if afficherCarburant {
                    Picker("Carburant", selection: $carburant) {
                        ForEach(TypeCarburant.allCases) { type in
                            Text(type.nom).tag(type.rawValue)
                        }
                    }
                    Stepper("Rayon : \(rayonStationKm) km", value: $rayonStationKm, in: 5...50, step: 5)
                }
            } header: {
                Label("Carburant", systemImage: "fuelpump.fill")
            } footer: {
                Text("Affiche la station la plus proche qui vend le carburant choisi, avec son prix.")
            }

            Section {
                Toggle("Aire de repos", isOn: $afficherPause)
                if afficherPause {
                    Stepper("Rayon : \(rayonAireKm) km", value: $rayonAireKm, in: 10...100, step: 10)
                }
            } header: {
                Label("Pause", systemImage: "cup.and.saucer.fill")
            } footer: {
                Text("Affiche l'aire de repos la plus proche.")
            }

            Section {
                Toggle("Actualisation automatique", isOn: $actualisationAuto)
                if actualisationAuto {
                    Picker("Actualiser toutes les", selection: $intervalleSecondes) {
                        Text("15 secondes").tag(15)
                        Text("30 secondes").tag(30)
                        Text("1 minute").tag(60)
                        Text("2 minutes").tag(120)
                        Text("5 minutes").tag(300)
                        Text("10 minutes").tag(600)
                    }
                }
            } header: {
                Label("Actualisation", systemImage: "arrow.triangle.2.circlepath")
            } footer: {
                Text("Continue écran verrouillé et sur CarPlay pendant le trajet. Quand plusieurs informations sont activées, elles s'affichent à tour de rôle.")
            }
        }
        // Applique tout de suite le nouveau réglage à la Live Activity en cours.
        .onChange(of: actualisationAuto) { CopiloteManager.shared.lancerActualisationSiBesoin() }
        .onChange(of: intervalleSecondes) { CopiloteManager.shared.lancerActualisationSiBesoin() }
        .navigationTitle("Réglages")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { ReglagesView() }
}
