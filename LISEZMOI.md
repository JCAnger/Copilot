# Copilote — prototype Live Activity CarPlay

Objectif : voir en vrai une Live Activity s'afficher dans le Dashboard CarPlay, à côté de Waze ou Plans, et la piloter avec Siri.

Pas d'entitlement CarPlay nécessaire : une Live Activity apparaît dans CarPlay même si l'app n'a pas d'interface CarPlay.

**Prérequis** : Xcode 26 ou plus récent, un iPhone sous iOS 26 ou plus récent, un câble USB.

---

## 1. Ouvrir le projet

Dézippe le dossier et double-clique sur **`Copilote.xcodeproj`**. Tout est déjà configuré :

- cible **Copilote** (l'app) avec `NSSupportsLiveActivities = YES`
- cible **CopiloteWidgetExtension** (la Live Activity), intégrée à l'app
- dossier `Shared/` partagé entre les deux cibles
- iOS 26 minimum, Swift 5

## 2. Signer

Sélectionne le projet → onglet **Signing & Capabilities** → choisis ton équipe dans *Team*, **pour les deux cibles** (Copilote et CopiloteWidgetExtension).

Les identifiants de bundle intègrent automatiquement ton Team ID (`com.demo.copilote.<TEAM>` et `….widget`), ils sont donc uniques sans rien modifier. Tu peux les remplacer par ton propre préfixe : celui du widget doit commencer par celui de l'app.

## 3. Lancer sur l'iPhone

1. Choisis le schéma **Copilote** et ton iPhone comme destination
2. Lance l'app sur ton iPhone (pas le simulateur iOS)
3. Appuie sur **Démarrer le copilote** → la Live Activity apparaît sur l'écran verrouillé et dans la Dynamic Island

## 4. Voir le rendu CarPlay

**Option A — CarPlay Simulator (recommandé, sans voiture)**
1. Télécharge **Additional Tools for Xcode** sur developer.apple.com → Downloads
2. Ouvre **CarPlay Simulator** sur ton Mac
3. Branche l'iPhone en USB → l'écran CarPlay apparaît sur le Mac
4. Lance un itinéraire dans Plans ou Waze, puis démarre le copilote dans l'app

**Option B — dans ta voiture**
Démarre le copilote, branche l'iPhone, lance Waze : la Live Activity rejoint la colonne de droite du Dashboard (avec Musique / Maison).

Le mode démo fait défiler 4 scénarios toutes les 8 s : parking → pause → carburant → ticket.

## 5. Tester Siri et le démarrage automatique

- **Siri** : « Dis Siri, démarre le copilote dans Copilote » / « Dis Siri, arrête Copilote »
  (les phrases contiennent le nom de l'app, c'est imposé par Apple)
- **Automatisation** : app Raccourcis → Automatisation → **+** → **CarPlay** → *Se connecte* → *Exécuter immédiatement* → action **Démarrer le copilote**.
  Le copilote démarre alors à chaque branchement en voiture, sans rien toucher.

---

## Limites du prototype (normales à ce stade)

- **Le défilement auto s'arrête quand l'app passe en arrière-plan** : iOS suspend l'app après quelques secondes. Garde l'app ouverte sur l'iPhone pendant le test, ou utilise Siri pour démarrer/arrêter. En production, les mises à jour viendront de notifications push ActivityKit (`pushType: .token`) ou de la localisation en arrière-plan.
- **Les scénarios sont fictifs** : la prochaine étape est de brancher les vraies données (position, durée de conduite, prix carburant, parkings) et de laisser l'IA choisir le scénario.
- **Le tap sur la Live Activity dans CarPlay ne fait rien d'utile** tant que l'app n'a pas d'interface CarPlay (entitlement nécessaire).

## Où regarder dans le code

- `.supplementalActivityFamilies([.small])` dans `CopiloteLiveActivity.swift` : la ligne qui rend la Live Activity éligible à CarPlay
- `@Environment(\.activityFamily)` : bascule entre la vue CarPlay (`.small`) et la vue écran verrouillé
- `LiveActivityIntent` dans `CopiloteIntents.swift` : permet à Siri et aux Raccourcis de démarrer l'activité
