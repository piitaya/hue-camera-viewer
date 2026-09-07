using Xunit;

namespace Hue.Core.Tests;

public sealed class PersistenceTests : IDisposable
{
    private readonly string directory = Path.Combine(Path.GetTempPath(), "Hue-Core-Tests", Guid.NewGuid().ToString("N"));

    [Fact]
    public void SettingsSurviveRestartWithAllUserChoices()
    {
        var path = Path.Combine(directory, "settings.json");
        var expected = new AppSettings
        {
            CameraId = "USB-camera-123", RotationQuarterTurns = 3,
            DockEdge = DockEdge.Bottom, IsDockCollapsed = true
        };
        new SettingsStore(path).Save(expected);
        Assert.Equal(expected, new SettingsStore(path).Load());
        Assert.Single(Directory.GetFiles(directory));
    }

    [Fact]
    public void MissingAndCorruptSettingsFallBackToDefaults()
    {
        var path = Path.Combine(directory, "settings.json");
        Assert.Equal(new AppSettings(), new SettingsStore(path).Load());
        Directory.CreateDirectory(directory);
        File.WriteAllText(path, "{incomplete");
        Assert.Equal(new AppSettings(), new SettingsStore(path).Load());
    }

    [Fact]
    public void OldOrInvalidPreferenceValuesAreNormalized()
    {
        var path = Path.Combine(directory, "settings.json");
        Directory.CreateDirectory(directory);
        File.WriteAllText(path, "{\"RotationQuarterTurns\":-1,\"DockEdge\":99,\"CameraId\":\" \"}");
        Assert.Equal(new AppSettings { RotationQuarterTurns = 3 }, new SettingsStore(path).Load());
    }

    [Fact]
    public async Task ConcurrentCapturesAreUniqueAndNeverOverwriteExistingFiles()
    {
        Directory.CreateDirectory(directory);
        var existing = Path.Combine(directory, "keep.png");
        await File.WriteAllBytesAsync(existing, [91]);
        var paths = await Task.WhenAll(Enumerable.Range(1, 24).Select(value =>
            CaptureFile.WriteAsync(directory, stream => stream.WriteAsync(new byte[] { (byte)value }).AsTask())));
        Assert.Equal(24, paths.Distinct().Count());
        for (var index = 0; index < paths.Length; index++)
            Assert.Equal(new byte[] { (byte)(index + 1) }, await File.ReadAllBytesAsync(paths[index]));
        Assert.Equal(new byte[] { 91 }, await File.ReadAllBytesAsync(existing));
        Assert.Equal(25, Directory.GetFiles(directory).Length);
    }

    [Fact]
    public async Task FailedCaptureDoesNotLeaveAPartialFile()
    {
        await Assert.ThrowsAsync<IOException>(() => CaptureFile.WriteAsync(directory, async stream =>
        {
            await stream.WriteAsync(new byte[] { 1, 2, 3 });
            Assert.Empty(Directory.GetFiles(directory, "*.png"));
            throw new IOException("Simulated encode failure.");
        }));
        Assert.Empty(Directory.GetFiles(directory));
    }

    public void Dispose()
    {
        if (Directory.Exists(directory)) Directory.Delete(directory, recursive: true);
    }
}
