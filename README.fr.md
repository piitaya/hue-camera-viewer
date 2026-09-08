# Hue Camera Viewer

<img src="assets/hue.png" width="96" alt="Icône de Hue Camera Viewer">

> Projet indépendant, non affilié à HUE. Cette application est compatible avec les caméras HUE.

[English](README.md) | **Français**

Une application simple pour les caméras de documents HUE et USB : affichage en direct,
rotation, zoom et gel de l’image, et captures PNG enregistrées sur le Bureau, avec une barre d’outils
déplaçable et repliable.

**Français et anglais · Applications natives pour macOS et Windows**

| Système | Configuration requise |
| --- | --- |
| macOS | macOS 13 ou ultérieur, sur Mac Intel ou Apple Silicon |
| Windows | Windows 10 (version 2004 ou ultérieure) sur x64 ; Windows 11 sur x64 ou ARM64 |

## Installation

**[Télécharger pour macOS](https://github.com/piitaya/hue-camera-viewer/releases/latest)** · **[Télécharger pour Windows](https://github.com/piitaya/hue-camera-viewer/releases/latest)**

Sur macOS, ouvrez le DMG et glissez Hue dans le dossier Applications.
Sur Windows, lancez `Hue-Setup.exe`, puis ouvrez Hue depuis le menu Démarrer.
Branchez votre caméra et autorisez son accès lorsque l’application le demande.

L’application macOS n’est pas notarisée et l’installateur Windows non signé peut afficher
un avertissement Microsoft SmartScreen. Des versions de test de chaque modification restent
disponibles trois jours dans les artefacts [GitHub Actions](https://github.com/piitaya/hue-camera-viewer/actions/workflows/build.yml).

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

Pour le développement, consultez le [README en anglais](README.md#repository).

Distribué sous [licence MIT](LICENSE).
