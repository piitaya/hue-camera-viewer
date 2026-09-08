using System.Globalization;

namespace Girafon.Windows;

internal static class Strings
{
    private static readonly bool French = CultureInfo.CurrentUICulture.TwoLetterISOLanguageName == "fr";

    public static string Get(string english) => French && Translations.TryGetValue(english, out string? translated)
        ? translated : english;

    private static readonly Dictionary<string, string> Translations = new()
    {
        ["Choose camera"] = "Choisir une caméra",
        ["Rotate left"] = "Tourner à gauche",
        ["Rotate right"] = "Tourner à droite",
        ["Capture image"] = "Capturer l’image",
        ["Hide controls"] = "Masquer les commandes",
        ["Show controls"] = "Afficher les commandes",
        ["Move controls"] = "Déplacer les commandes",
        ["Top"] = "En haut",
        ["Right"] = "À droite",
        ["Bottom"] = "En bas",
        ["Left"] = "À gauche",
        ["Starting camera…"] = "Démarrage de la caméra…",
        ["Connect a camera to begin."] = "Branchez une caméra pour commencer.",
        ["Camera disconnected. Reconnect it or choose another camera."] = "Caméra déconnectée. Rebranchez-la ou choisissez une autre caméra.",
        ["Allow desktop apps to access your camera in Windows Settings."] = "Autorisez les applications de bureau à accéder à votre caméra dans les paramètres Windows.",
        ["Camera unavailable. Close other camera apps and try again."] = "Caméra indisponible. Fermez les autres applications qui l’utilisent et réessayez.",
        ["Could not start the camera. Choose a camera to try again."] = "Impossible de démarrer la caméra. Choisissez une caméra pour réessayer.",
        ["Open camera settings"] = "Ouvrir les paramètres de la caméra",
        ["No cameras found"] = "Aucune caméra détectée",
        ["Demo"] = "Démonstration",
        ["Image saved to Desktop"] = "Image enregistrée sur le Bureau",
        ["Image saved"] = "Image enregistrée",
        ["Could not save the image. Check the folder permissions and available space."] = "Impossible d’enregistrer l’image. Vérifiez les autorisations du dossier et l’espace disponible.",
        ["Settings could not be saved."] = "Les réglages n’ont pas pu être enregistrés."
    };
}
