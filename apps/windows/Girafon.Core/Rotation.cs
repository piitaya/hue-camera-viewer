namespace Girafon.Core;

public static class Rotation
{
    public static int Normalize(int quarterTurns) => ((quarterTurns % 4) + 4) % 4;
    public static int Clockwise(int quarterTurns) => (Normalize(quarterTurns) + 1) % 4;
    public static int CounterClockwise(int quarterTurns) => (Normalize(quarterTurns) + 3) % 4;

    public static (int Width, int Height) Dimensions(int width, int height, int quarterTurns)
        => Normalize(quarterTurns) % 2 == 0 ? (width, height) : (height, width);

    public static byte[] RotateBgra(ReadOnlySpan<byte> pixels, int width, int height, int quarterTurns)
    {
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(width);
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(height);
        if (pixels.Length != checked(width * height * 4))
            throw new ArgumentException("The pixel buffer does not match the image dimensions.", nameof(pixels));

        var turns = Normalize(quarterTurns);
        var (outputWidth, _) = Dimensions(width, height, turns);
        var output = new byte[pixels.Length];
        for (var y = 0; y < height; y++)
        for (var x = 0; x < width; x++)
        {
            var (destinationX, destinationY) = turns switch
            {
                1 => (height - 1 - y, x),
                2 => (width - 1 - x, height - 1 - y),
                3 => (y, width - 1 - x),
                _ => (x, y)
            };
            pixels.Slice((y * width + x) * 4, 4)
                .CopyTo(output.AsSpan((destinationY * outputWidth + destinationX) * 4, 4));
        }
        return output;
    }
}

/// The preview zoom is a display setting: captures keep the full image.
public static class Zoom
{
    public const double Minimum = 1;
    public const double Maximum = 4;
    public const double Step = 1.25;

    public static double Clamp(double value)
    {
        if (double.IsNaN(value)) return Minimum;
        var clamped = Math.Clamp(value, Minimum, Maximum);
        return clamped < 1.001 ? Minimum : clamped;
    }

    public static double In(double value) => Clamp(value * Step);
    public static double Out(double value) => Clamp(value / Step);
    public static bool IsZoomed(double value) => value > 1.001;
    public static int Percent(double value) => (int)Math.Round(value * 100);

    /// Panning stops where the magnified image meets the edge of the viewport.
    public static (double X, double Y) ClampPan(double x, double y, double zoom, double fittedWidth, double fittedHeight,
        double viewportWidth, double viewportHeight)
    {
        var limitX = Math.Max(0, (fittedWidth * zoom - viewportWidth) / 2);
        var limitY = Math.Max(0, (fittedHeight * zoom - viewportHeight) / 2);
        return (Math.Clamp(x, -limitX, limitX), Math.Clamp(y, -limitY, limitY));
    }
}
