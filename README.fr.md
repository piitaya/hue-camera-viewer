# Girafon

<img src="assets/girafon.png" width="96" alt="Icône de Girafon">

[English](README.md) | **Français**

Un visualiseur de documents simple : affichage en direct, rotation à 90° et captures
PNG enregistrées sur le Bureau, avec une barre d’outils déplaçable et repliable.

**Français et anglais · Applications natives pour macOS et Windows**

| Système | Configuration requise |
| --- | --- |
| macOS | macOS 13 ou ultérieur, sur Mac Intel ou Apple Silicon |
| Windows | Windows 10 (version 2004 ou ultérieure) sur x64 ; Windows 11 sur x64 ou ARM64 |

## Installation

Téléchargez les installateurs de test Girafon depuis une [compilation GitHub Actions réussie](https://github.com/piitaya/girafon/actions/workflows/build.yml).
Sur macOS, ouvrez le DMG et glissez Girafon dans le dossier Applications.
Sur Windows, lancez `Girafon-Setup.exe`, puis ouvrez Girafon depuis le menu Démarrer.
Branchez votre caméra et autorisez son accès lorsque l’application le demande.

Ces versions servent aux tests : la version macOS n’est pas notarisée et l’installateur
Windows non signé peut afficher un avertissement Microsoft SmartScreen.
Les [versions publiées](https://github.com/piitaya/girafon/releases) restent disponibles séparément.

## Caméras

Girafon utilise les caméras accessibles depuis le système d’exploitation.

| Famille de caméras | Connexion |
| --- | --- |
| [HUE HD Pro](https://huehd.com/pro/) (1080p) | USB UVC |
| [HUE HD](https://huehd.com/products/hue-hd-camera/) (modèles UVC 720p et 1080p) | USB UVC |
| Autres webcams et visualiseurs USB | Vidéo UVC standard |
| Caméras intégrées aux Mac et PC | Prise en charge par le système |

Cette liste couvre des familles de caméras, pas tous les modèles testés. La compatibilité
peut varier selon l’appareil ; les anciens modèles nécessitant un pilote propriétaire ne sont pas couverts.
Girafon est un projet indépendant, non affilié aux fabricants de caméras cités ici.

Pour le développement, consultez le [README en anglais](README.md#repository).

Distribué sous [licence MIT](LICENSE).
