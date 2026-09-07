# Hue

Visualiseur macOS natif en français pour caméra HUE/USB : aperçu en direct,
rotations à 90° et capture PNG sur le Bureau.
L’image occupe tout le contenu d’une fenêtre macOS classique. Un dock escamotable
contient les commandes et le choix de caméra. Il utilise Liquid Glass sur macOS 26+
et un matériau translucide classique sur macOS 13 à 15. Il peut être déplacé
vers les quatre bords avec aperçu de sa position et animation au lâcher.
Il est vertical sur les côtés et horizontal en haut ou en bas. Le plein écran
s’utilise via le bouton vert standard de macOS.
Les commandes de l’application ne définissent aucun raccourci clavier personnalisé.

## État du projet

Cette version cible **les Mac Intel et Apple Silicon avec macOS 13 ou ultérieur**.
Le même bundle contient les deux architectures, `x86_64` et `arm64`.
Les tests automatisés utilisent des images synthétiques. Les essais sur macOS 13,
sur un Mac Intel physique, avec une vraie HUE et les premiers accès caméra/Bureau
restent à faire. Une exécution via Rosetta ne remplace pas ces validations matérielles.

## Construire

Mac Intel ou Apple Silicon disposant d’un Xcode fournissant le SDK macOS 26+.
Le SDK récent permet de compiler Liquid Glass avec une alternative pour les anciens
systèmes ; l’application produite déclare macOS 13 minimum.
La compilation de l’application ne demande aucune bibliothèque tierce ni accès réseau.

```sh
bash Scripts/build.sh
open build/Hue.app
```

Le script compile séparément pour `arm64-apple-macos13.0` et
`x86_64-apple-macos13.0`, assemble les exécutables avec `lipo`, vérifie les deux
architectures, puis signe le bundle complet. L’outil de génération d’icône est compilé
pour la machine de construction uniquement.
Le bundle produit est signé localement (ad hoc), avec Hardened Runtime et
l’autorisation caméra. Il n’utilise pas App Sandbox ; macOS contrôle l’accès
à la caméra et au Bureau avec ses autorisations de confidentialité.
Pour signer avec un certificat Developer ID existant, définir
`HUE_SIGNING_IDENTITY="Developer ID Application: …"` avant la compilation.
La notarisation nécessite vos propres identifiants Apple Developer.

## Vérifier

```sh
bash Scripts/test.sh
open -na build/Hue.app --args --demo
```

Le mode `--demo`, réservé aux tests et au développement, affiche une mire fixe
simple, sans texte et sans activer la caméra.
Les captures de démonstration sont placées dans le dossier temporaire Hue-Demo,
ou dans le dossier passé après `--capture-directory`, créé si nécessaire.
Ce mode ne modifie pas les préférences de l’utilisateur.
Les tests du pipeline vérifient les pixels des quatre rotations,
les dimensions, les décalages d’origine et l’encodage PNG sans collision.
Les tests du dock couvrent les quatre bords, l’aimantation et les petites fenêtres.
Un test de capture vérifie qu’une demande effectuée immédiatement après une rotation
attend la nouvelle image et enregistre un seul PNG, avec les bons pixels et dimensions.
Ces tests utilisent des images synthétiques ; la caméra HUE réelle reste à valider.
Core Image a besoin d’un accès au rendu graphique ; un bac à sable de commande peut
bloquer son exécution même si l’application fonctionne dans une session macOS normale.

Les tests ciblent macOS 13 et s’exécutent par défaut sur l’architecture du processus
hôte. Sur Apple Silicon avec Rosetta déjà installé, la commande suivante vérifie
également les exécutables Intel ; le script n’installe pas Rosetta :

```sh
HUE_TEST_ARCH=x86_64 bash Scripts/test.sh
```

Pour inspecter uniquement le rendu du dock classique sur macOS 26+, lancer :

```sh
open -na build/Hue.app --args --demo --classic-dock
```

L’option `--classic-dock` fonctionne aussi sans `--demo`. Elle force seulement le
matériau classique ; elle ne simule ni macOS 13 ni ses API. Sans `--demo`, l’application
utilise la vraie caméra et les captures vont sur le Bureau.

## Créer le DMG

Le packaging utilise Python 3.10+ et `dmgbuild`. Installez ses dépendances une fois
dans un environnement isolé (connexion réseau requise pour cette installation) :

```sh
python3 -m venv .venv-dmg
.venv-dmg/bin/python -m pip install -r Scripts/requirements-dmg.txt
bash Scripts/package.sh
```

Le DMG s’ouvre sur une fenêtre d’installation illustrée : Hue à gauche,
une flèche, et le dossier Applications à droite. Il contient uniquement l’application
et le lien vers Applications comme éléments visibles. Le guide est fourni séparément.
Le fond Retina et les positions Finder sont générés sans automatiser Finder.
Pour réutiliser un outil déjà installé, définir `HUE_DMGBUILD` avec son chemin.
Pour refaire uniquement le DMG d’une application déjà construite et signée,
définir `HUE_APP_PATH` avec le chemin de ce bundle.
Le fichier produit par défaut est `build/Hue-1.0-Universal.dmg`. Le script vérifie
la présence des deux architectures, la cible macOS 13 de chacune, la version minimum
du bundle et sa signature, avant et après la création du DMG. Il refuse ainsi un ancien
bundle Apple Silicon ciblant macOS 26 passé avec `HUE_APP_PATH`.

## Organisation

- Sources/CameraEngine.swift : autorisation, découverte USB, session vidéo, reconnexion.
- Sources/ImagePipeline.swift : transformation unique pour aperçu/capture, PNG atomique.
- Sources/AppModel.swift : préférences et captures en arrière-plan.
- Sources/ContentView.swift : interface SwiftUI.
- Sources/DockGeometry.swift : placement et aimantation du dock.
- Sources/HueApp.swift : fenêtre et menus macOS.

L’image exportée provient de la même image rendue que l’aperçu. Les bandes de cadrage
et les éléments d’interface ne sont pas enregistrés. Aucun microphone n’est ouvert.
