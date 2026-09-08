namespace Hue.Windows;

// Lucide 1.43.0, using the same 24-unit vectors as the macOS toolbar.
// SVG circles and rounded rectangles are expressed as equivalent path segments.
// Source and license: assets/licenses/lucide.txt (bundled as Lucide-LICENSE.txt).
internal static class DockIcons
{
    public const string Source =
        "M10 8 H20 A2 2 0 0 1 22 10 V20 A2 2 0 0 1 20 22 H10 A2 2 0 0 1 8 20 V10 A2 2 0 0 1 10 8 Z " +
        "M4 16 c-1.1 0 -2 -.9 -2 -2 V4 c0 -1.1 .9 -2 2 -2 h10 c1.1 0 2 .9 2 2";

    public const string Capture =
        "M13.997 4 a2 2 0 0 1 1.76 1.05 l.486 .9 A2 2 0 0 0 18.003 7 H20 a2 2 0 0 1 2 2 v9 a2 2 0 0 1 -2 2 H4 a2 2 0 0 1 -2 -2 V9 a2 2 0 0 1 2 -2 h1.997 a2 2 0 0 0 1.759 -1.048 l.489 -.904 A2 2 0 0 1 10.004 4 Z " +
        "M15 13 A3 3 0 1 0 9 13 A3 3 0 1 0 15 13 Z";

    public const string Zoom =
        "M19 11 A8 8 0 1 0 3 11 A8 8 0 1 0 19 11 Z M21 21 L16.65 16.65 M11 8 V14 M8 11 H14";

    public const string RotateLeft =
        "M3 12 a9 9 0 1 0 9 -9 a9.75 9.75 0 0 0 -6.74 2.74 L3 8 M3 3 V8 H8";

    public const string RotateRight =
        "M21 12 a9 9 0 1 1 -9 -9 c2.52 0 4.93 1 6.74 2.74 L21 8 M21 3 V8 H16";

    public const string Grip =
        "M10 5 a1 1 0 1 0 -2 0 a1 1 0 1 0 2 0 Z " +
        "M10 12 a1 1 0 1 0 -2 0 a1 1 0 1 0 2 0 Z " +
        "M10 19 a1 1 0 1 0 -2 0 a1 1 0 1 0 2 0 Z " +
        "M16 5 a1 1 0 1 0 -2 0 a1 1 0 1 0 2 0 Z " +
        "M16 12 a1 1 0 1 0 -2 0 a1 1 0 1 0 2 0 Z " +
        "M16 19 a1 1 0 1 0 -2 0 a1 1 0 1 0 2 0 Z";

    public const string ChevronRight = "M9 18 L15 12 L9 6";
}
