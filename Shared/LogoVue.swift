import SwiftUI
import UIKit

// ⚠️ Ce fichier doit appartenir AUX DEUX cibles : l'app ET l'extension widget.

/// Icône d'une information du copilote.
/// - Station reconnue avec un fichier `logo-<enseigne>.png` dans `Shared/Logos` : le logo.
/// - Station reconnue sans fichier : pastille aux couleurs de l'enseigne.
/// - Sinon : le pictogramme du scénario.
struct LogoVue: View {
    let etat: CopiloteAttributes.ContentState
    var taille: CGFloat = 34
    var couleurSymbole: Color = .blue

    var body: some View {
        if etat.scenario == .carburant, let enseigne = etat.enseigne {
            if let image = UIImage(named: "logo-\(enseigne.rawValue)") {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: taille, height: taille)
                    .clipShape(RoundedRectangle(cornerRadius: taille * 0.28))
            } else {
                let c = enseigne.couleur
                Text(enseigne.initiales)
                    .font(.system(size: taille * 0.42, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .padding(2)
                    .frame(width: taille, height: taille)
                    .background(Color(red: c.rouge, green: c.vert, blue: c.bleu),
                                in: RoundedRectangle(cornerRadius: taille * 0.28))
                    .accessibilityLabel(enseigne.nom)
            }
        } else {
            Image(systemName: etat.scenario.symbol)
                .font(.system(size: taille * 0.55, weight: .semibold))
                .foregroundStyle(couleurSymbole)
                .frame(width: taille, height: taille)
        }
    }
}
