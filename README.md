# Hue

Visualiseur macOS natif en français pour caméra HUE/USB : aperçu en direct,
rotations à 90° et capture PNG sur le Bureau.
L’image occupe tout le contenu d’une fenêtre macOS classique. Un dock Liquid Glass
escamotable contient les commandes et le choix de caméra. Il peut être déplacé
vers les quatre bords avec aperçu de sa position et animation au lâcher.
Il est vertical sur les côtés et horizontal en haut ou en bas. Le plein écran
s’utilise via le bouton vert standard de macOS.
Les commandes de l’application ne définissent aucun raccourci clavier personnalisé.

## État du projet

Cette première version cible **Apple Silicon et macOS 26 ou ultérieur**.
Une version universelle Intel / Apple Silicon avec macOS 13 minimum est prévue ;
elle n’est pas encore implémentée dans cette révision.
Les tests automatisés utilisent des images synthétiques. Les essais avec une vraie
HUE, les premiers accès caméra/Bureau et la validation sur un Mac Intel restent à faire.

## Construire

Mac Apple Silicon avec macOS 26+ et Xcode fournissant le SDK macOS 26+.
Aucune bibliothèque tierce ni dépendance réseau.

```sh
bash Scripts/build.sh
open build/Hue.app
```

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

Le mode `--demo` utilise un document synthétique, sans activer la caméra.
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

## Organisation

- Sources/CameraEngine.swift : autorisation, découverte USB, session vidéo, reconnexion.
- Sources/ImagePipeline.swift : transformation unique pour aperçu/capture, PNG atomique.
- Sources/AppModel.swift : préférences et captures en arrière-plan.
- Sources/ContentView.swift : interface SwiftUI.
- Sources/DockGeometry.swift : placement et aimantation du dock.
- Sources/HueApp.swift : fenêtre et menus macOS.

L’image exportée provient de la même image rendue que l’aperçu. Les bandes de cadrage
et les éléments d’interface ne sont pas enregistrés. Aucun microphone n’est ouvert.
