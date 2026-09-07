namespace Hue.Windows;

internal sealed record LaunchOptions(bool Demo, bool SmokeTest, string? CaptureDirectory)
{
    public static LaunchOptions Parse(string[] arguments)
    {
        bool smoke = arguments.Contains("--smoke-test");
        bool demo = smoke || arguments.Contains("--demo");
        int directoryIndex = Array.IndexOf(arguments, "--capture-directory");
        string? directory = directoryIndex >= 0 && directoryIndex + 1 < arguments.Length
            ? Path.GetFullPath(arguments[directoryIndex + 1])
            : demo ? Path.Combine(Path.GetTempPath(), "Hue-Demo", Guid.NewGuid().ToString("N")) : null;
        return new(demo, smoke, directory);
    }
}
