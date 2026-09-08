namespace Girafon.Core;

public enum DockEdge { Top, Right, Bottom, Left }

public readonly record struct DockPoint(double X, double Y);

public static class DockGeometry
{
    public static DockEdge NearestEdge(double x, double y, double width, double height,
        DockEdge current = DockEdge.Right)
    {
        width = Math.Max(0, width);
        height = Math.Max(0, height);
        x = Math.Clamp(x, 0, width);
        y = Math.Clamp(y, 0, height);
        var distances = new Dictionary<DockEdge, double>
        {
            [DockEdge.Top] = y,
            [DockEdge.Right] = width - x,
            [DockEdge.Bottom] = height - y,
            [DockEdge.Left] = x
        };
        var nearest = distances.Min(pair => pair.Value);
        // Keep the preview steady when the pointer moves near a corner.
        return distances.TryGetValue(current, out var currentDistance) && currentDistance <= nearest + 16
            ? current
            : distances.First(pair => pair.Value == nearest).Key;
    }

    public static DockPoint Position(DockEdge edge, double width, double height,
        double dockWidth, double dockHeight, double margin = 16)
    {
        var point = edge switch
        {
            DockEdge.Top => new DockPoint((width - dockWidth) / 2, margin),
            DockEdge.Bottom => new DockPoint((width - dockWidth) / 2, height - dockHeight - margin),
            DockEdge.Left => new DockPoint(margin, (height - dockHeight) / 2),
            _ => new DockPoint(width - dockWidth - margin, (height - dockHeight) / 2)
        };
        return Clamp(point, width, height, dockWidth, dockHeight, margin);
    }

    public static DockPoint Clamp(DockPoint point, double width, double height,
        double dockWidth, double dockHeight, double margin = 16)
    {
        static double Axis(double position, double available, double size, double padding)
        {
            var maximum = Math.Max(0, available - Math.Max(0, size));
            var inset = Math.Min(Math.Max(0, padding), maximum / 2);
            return Math.Clamp(position, inset, maximum - inset);
        }
        return new DockPoint(Axis(point.X, width, dockWidth, margin),
            Axis(point.Y, height, dockHeight, margin));
    }
}
