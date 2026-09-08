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
