import SwiftUI
import WidgetKit

// Point d'entrée de l'extension : elle ne contient que la Live Activity.

@main
struct CopiloteWidgetBundle: WidgetBundle {
    var body: some Widget {
        CopiloteLiveActivity()
    }
}
