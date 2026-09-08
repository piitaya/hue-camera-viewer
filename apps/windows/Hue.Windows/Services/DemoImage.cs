using System.Runtime.InteropServices.WindowsRuntime;
using Windows.Graphics.Imaging;

namespace Hue.Windows.Services;

internal static class DemoImage
{
    public static SoftwareBitmap Create()
    {
        const int width = 640, height = 480;
        var pixels = new byte[width * height * 4];
        for (var y = 0; y < height; y++)
        for (var x = 0; x < width; x++)
        {
            var circle = (x - 210) * (x - 210) + (y - 240) * (y - 240) < 80 * 80;
            var square = x is > 370 and < 510 && y is > 170 and < 310;
            var index = (y * width + x) * 4;
            pixels[index] = circle ? (byte)160 : square ? (byte)222 : (byte)235;
            pixels[index + 1] = circle ? (byte)187 : square ? (byte)167 : (byte)243;
            pixels[index + 2] = circle ? (byte)91 : square ? (byte)105 : (byte)248;
            pixels[index + 3] = 255;
        }
        var bitmap = new SoftwareBitmap(BitmapPixelFormat.Bgra8, width, height, BitmapAlphaMode.Premultiplied);
        bitmap.CopyFromBuffer(pixels.AsBuffer());
        return bitmap;
    }
}
