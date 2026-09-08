# Hue Camera Viewer

<img src="assets/hue.png" width="96" alt="Icône de Hue Camera Viewer">

[![Dernière version](https://img.shields.io/github/v/release/piitaya/hue-camera-viewer?display_name=tag&label=version)](https://github.com/piitaya/hue-camera-viewer/releases/latest)

**[Télécharger pour macOS](https://github.com/piitaya/hue-camera-viewer/releases/latest/download/Hue-Camera-Viewer-macOS.dmg)** · **[Télécharger pour Windows](https://github.com/piitaya/hue-camera-viewer/releases/latest/download/Hue-Camera-Viewer-Windows.exe)** · [Toutes les versions](https://github.com/piitaya/hue-camera-viewer/releases)

[English](README.md) | **Français**

Une application simple pour les caméras de documents HUE et USB. Branchez la caméra, montrez
la page à l’écran ou au vidéoprojecteur, et enregistrez une image quand vous en avez besoin.
Applications natives pour macOS et Windows, en français et en anglais.

> Projet indépendant, non affilié à HUE. Cette application est compatible avec les caméras HUE.

## Fonctionnalités

- Aperçu en direct de la caméra, plein cadre dans la fenêtre, avec la caméra HUE choisie automatiquement.
- Rotation par quart de tour, mémorisée d’un lancement à l’autre.
- Zoom de 100 à 400 % au curseur, à la molette ou au pincement sur le trackpad.
- Gel de l’image le temps de tourner une page ; la caméra continue de tourner, la reprise est instantanée.
- Captures PNG en pleine résolution, enregistrées sur le Bureau en un clic.
- Une barre d’outils à déplacer sur n’importe quel bord de la fenêtre ou à masquer, avec un raccourci clavier pour tout.

## Installation

**macOS 13 ou ultérieur**, Intel et Apple Silicon : ouvrez le DMG et glissez Hue dans le dossier
Applications.

**Windows 10 (2004) ou ultérieur**, x64 et ARM64 : lancez l’installateur, puis ouvrez Hue depuis
le menu Démarrer. L’installateur n’est pas signé : si SmartScreen affiche un avertissement,
choisissez « Informations complémentaires », puis « Exécuter quand même ».

Au premier lancement, autorisez l’accès à la caméra quand le système le demande. L’application
choisit d’elle-même la caméra HUE quand elle est branchée ; le bouton caméra permet d’en choisir une autre.

## Utilisation

La barre d’outils est posée sur un bord de la fenêtre. Glissez sa poignée pour la déplacer vers
un autre bord, et utilisez le chevron pour la masquer ou l’afficher.

| Bouton | Ce qu’il fait |
| --- | --- |
| Caméra | Choisir la caméra ; ouvre aussi la liste des raccourcis clavier |
| Tourner à gauche / à droite | Tourner l’image d’un quart de tour ; le choix est mémorisé |
| Loupe | Zoomer l’aperçu de 100 à 400 % ; la molette et le pincement sur le trackpad zooment aussi, et une image zoomée se déplace à la souris |
| Capture | Enregistrer un PNG en pleine résolution sur le Bureau |
| Flocon | Figer l’image le temps de tourner une page ou de déplacer la caméra ; rotation, zoom et capture continuent de fonctionner sur l’image figée |

| Action | macOS | Windows |
| --- | --- | --- |
| Capture sur le Bureau | ⌘S | Ctrl+S |
| Tourner à gauche / à droite | ⌘← / ⌘→ | Ctrl+← / Ctrl+→ |
| Zoom avant / arrière / 100 % | ⌘+ / ⌘− / ⌘0 | Ctrl++ / Ctrl+− / Ctrl+0 |
| Figer ou reprendre l’image | ⌘F | Ctrl+F |
| Masquer ou afficher la barre | ⌥⌘T | Ctrl+T |

## Caméras

Hue Camera Viewer utilise les caméras accessibles depuis le système d’exploitation.

| Famille de caméras | Connexion |
| --- | --- |
| [HUE HD Pro](https://huehd.com/pro/) (1080p) | USB UVC |
| [HUE HD](https://huehd.com/products/hue-hd-camera/) (modèles UVC 720p et 1080p) | USB UVC |
| Autres webcams et visualiseurs USB | Vidéo UVC standard |
| Caméras intégrées aux Mac et PC | Prise en charge par le système |

Cette liste couvre des familles de caméras, pas tous les modèles testés. La compatibilité
peut varier selon l’appareil ; les anciens modèles nécessitant un pilote propriétaire ne sont pas couverts.
Hue Camera Viewer est un projet indépendant, non affilié à HUE ni aux autres fabricants de caméras cités ici.

Pour le développement, consultez le [README en anglais](README.md#development).

Distribué sous [licence MIT](LICENSE).
