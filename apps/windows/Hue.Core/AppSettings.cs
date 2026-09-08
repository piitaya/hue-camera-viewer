using System.Text.Json;

namespace Hue.Core;

public sealed record AppSettings
{
    public string? CameraId { get; init; }
    public int RotationQuarterTurns { get; init; }
    public DockEdge DockEdge { get; init; } = DockEdge.Right;
    public bool IsDockCollapsed { get; init; }

    public AppSettings Normalize() => this with
    {
        CameraId = string.IsNullOrWhiteSpace(CameraId) ? null : CameraId,
        RotationQuarterTurns = Rotation.Normalize(RotationQuarterTurns),
        DockEdge = Enum.IsDefined(DockEdge) ? DockEdge : DockEdge.Right
    };
}

public sealed class SettingsStore
{
    private readonly string filePath;
    private readonly object sync = new();

    public SettingsStore(string? filePath = null)
    {
        this.filePath = filePath ?? Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Hue", "settings.json");
    }

    public AppSettings Load()
    {
        lock (sync)
        {
            try
            {
                return JsonSerializer.Deserialize<AppSettings>(File.ReadAllText(filePath))?.Normalize() ?? new();
            }
            catch (Exception error) when (error is IOException or UnauthorizedAccessException or JsonException)
            {
                return new();
            }
        }
    }

    public void Save(AppSettings settings)
    {
        lock (sync)
        {
            var path = Path.GetFullPath(filePath);
            Directory.CreateDirectory(Path.GetDirectoryName(path)!);
            var temporary = path + "." + Guid.NewGuid().ToString("N") + ".tmp";
            try
            {
                using (var stream = new FileStream(temporary, FileMode.CreateNew, FileAccess.Write, FileShare.None))
                {
                    JsonSerializer.Serialize(stream, settings.Normalize());
                    stream.Flush(true);
                }
                File.Move(temporary, path, overwrite: true);
            }
            finally
            {
                if (File.Exists(temporary)) File.Delete(temporary);
            }
        }
    }
}
