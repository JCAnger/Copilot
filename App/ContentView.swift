import SwiftUI

/// Accueil : démarrer / actualiser / arrêter le copilote, et accéder aux réglages.
/// Style : Aqua, pastels bleu-vert, animations douces.
struct ContentView: View {
    @State private var manager = CopiloteManager.shared
    @AppStorage(Reglages.Cle.actualisationAuto) private var actualisationAuto = Reglages.Defaut.actualisationAuto

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.86, green: 0.93, blue: 1.0),
                             Color(red: 0.86, green: 0.97, blue: 0.92)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 24) {
                    entete
                    apercu
                    commandes
                    Spacer()
                    aide
                }
                .padding(24)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        ReglagesView()
                    } label: {
                        Label("Réglages", systemImage: "gearshape.fill")
                    }
                }
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: manager.scenarioCourant)
        .animation(.easeInOut(duration: 0.3), value: manager.estActif)
        .task { await manager.demanderNotifications() }
    }

    // MARK: - Sections

    private var entete: some View {
        VStack(spacing: 6) {
            Image(systemName: "car.side.fill")
                .font(.system(size: 44))
                .foregroundStyle(.blue.gradient)
            Text("Copilote")
                .font(.largeTitle.bold())
            Text(manager.estActif ? "Live Activity active" : "Inactif")
                .font(.subheadline)
                .foregroundStyle(manager.estActif ? .green : .secondary)
            Text(manager.etatNotifications)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 20)
    }

    @ViewBuilder
    private var apercu: some View {
        if let etat = manager.scenarioCourant {
            HStack(spacing: 14) {
                LogoVue(etat: etat, taille: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(etat.titre).font(.headline)
                    Text(etat.detail).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Text(etat.valeur)
                    .font(.title3.bold())
                    .foregroundStyle(.green)
            }
            .padding()
            .background(.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 18))
            .shadow(color: .blue.opacity(0.12), radius: 10, y: 4)
            .transition(.scale(scale: 0.95).combined(with: .opacity))
            .id(etat)
        }
    }

    private var commandes: some View {
        VStack(spacing: 12) {
            if !manager.liveActivitiesAutorisees {
                Label("Live Activities désactivées dans Réglages", systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }

            if let erreur = manager.messageErreur, !manager.estActif {
                Label(erreur, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.leading)
            }

            if manager.estActif {
                Button {
                    Task { await manager.scenarioSuivant() }
                } label: {
                    Label("Actualiser", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)

                Toggle("Actualisation automatique", isOn: $actualisationAuto)
                    .onChange(of: actualisationAuto) { manager.lancerActualisationSiBesoin() }
                    .padding(.horizontal, 4)

                Button(role: .destructive) {
                    Task { await manager.arreter() }
                } label: {
                    Label("Arrêter", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            } else {
                Button {
                    Task { await manager.demarrer() }
                } label: {
                    Label("Démarrer le copilote", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .controlSize(.large)
            }
        }
    }

    private var aide: some View {
        Text("Astuce : « Dis Siri, démarre le copilote dans \(Bundle.main.displayName) »")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
    }
}

private extension Bundle {
    var displayName: String {
        object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "l'app"
    }
}

#Preview { ContentView() }
