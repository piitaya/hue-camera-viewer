using Hue.Core;

namespace Hue.Windows;

internal readonly record struct DockPresentation(DockEdge Edge, double X, double Y, double Width, double Height,
    double ExpandedOpacity, double CollapsedOpacity);

// A finite spring keeps layout, clipping, and input geometry on the same frame.
// Retargeting starts from the last displayed presentation, including its opacity.
internal sealed class DockMotion(DockPresentation from, DockPresentation target, double startedAt,
    double response, double damping)
{
    public DockPresentation Target { get; } = target;

    public bool IsComplete(double now) => now - startedAt >= response * 1.6;

    public DockPresentation Sample(double now)
    {
        double elapsed = Math.Max(0, now - startedAt);
        if (IsComplete(now)) return Target;

        double time = elapsed / response;
        double frequency = 2 * Math.PI;
        double dampedFrequency = frequency * Math.Sqrt(1 - damping * damping);
        double progress = 1 - Math.Exp(-damping * frequency * time)
            * (Math.Cos(dampedFrequency * time)
                + damping / Math.Sqrt(1 - damping * damping) * Math.Sin(dampedFrequency * time));

        double expanded;
        double collapsed;
        DockEdge edge = Target.Edge;
        if (from.Edge != Target.Edge)
        {
            // Reorient only while the old controls are faded out, never while
            // a horizontal row is still visibly arranged in a vertical capsule.
            const double fadeOut = 0.07;
            if (elapsed < fadeOut)
            {
                edge = from.Edge;
                expanded = from.ExpandedOpacity * (1 - Fade(elapsed / fadeOut));
                collapsed = from.CollapsedOpacity * (1 - Fade(elapsed / fadeOut));
            }
            else
            {
                double fade = Fade((elapsed - fadeOut) / 0.16);
                expanded = Target.ExpandedOpacity * fade;
                collapsed = Target.CollapsedOpacity * fade;
            }
        }
        else
        {
            double fade = Fade(elapsed / 0.18);
            expanded = Lerp(from.ExpandedOpacity, Target.ExpandedOpacity, fade);
            collapsed = Lerp(from.CollapsedOpacity, Target.CollapsedOpacity, fade);
        }

        return new DockPresentation(edge,
            Lerp(from.X, Target.X, progress), Lerp(from.Y, Target.Y, progress),
            Lerp(from.Width, Target.Width, progress), Lerp(from.Height, Target.Height, progress),
            expanded, collapsed);
    }

    private static double Lerp(double from, double to, double progress) => from + (to - from) * progress;

    private static double Fade(double progress)
    {
        double value = Math.Clamp(progress, 0, 1);
        return value * value * (3 - 2 * value);
    }
}
