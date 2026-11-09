import AppIntents

// Ces intents rendent le copilote pilotable par Siri, par l'app Raccourcis
// et par une automatisation « Quand CarPlay se connecte ».
// LiveActivityIntent garantit que perform() s'exécute dans le processus de l'app,
// le seul autorisé à démarrer une Live Activity.

struct DemarrerCopiloteIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Démarrer le copilote"
    static let description = IntentDescription("Affiche le copilote dans CarPlay et sur l'écran verrouillé.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let demarre = await CopiloteManager.shared.demarrer()
        if demarre {
            return .result(dialog: "Copilote démarré. Bonne route !")
        }
        let raison = await CopiloteManager.shared.messageErreur ?? "Impossible de démarrer le copilote."
        return .result(dialog: IntentDialog(stringLiteral: raison))
    }
}

struct ArreterCopiloteIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Arrêter le copilote"

    func perform() async throws -> some IntentResult & ProvidesDialog {
        await CopiloteManager.shared.arreter()
        return .result(dialog: "Copilote arrêté.")
    }
}

struct CopiloteShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: DemarrerCopiloteIntent(),
            phrases: [
                "Démarre le copilote dans \(.applicationName)",
                "Lance \(.applicationName)",
                "Démarre \(.applicationName)"
            ],
            shortTitle: "Démarrer le copilote",
            systemImageName: "car.fill"
        )
        AppShortcut(
            intent: ArreterCopiloteIntent(),
            phrases: [
                "Arrête le copilote dans \(.applicationName)",
                "Arrête \(.applicationName)"
            ],
            shortTitle: "Arrêter le copilote",
            systemImageName: "stop.circle"
        )
    }
}
