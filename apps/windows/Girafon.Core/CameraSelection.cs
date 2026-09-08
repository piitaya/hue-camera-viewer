namespace Girafon.Core;

public sealed record CameraChoice(string Id, string Name, bool IsExternal = true)
{
    public bool IsPreferredDocumentCamera => Name.Contains("hue", StringComparison.OrdinalIgnoreCase);
}

public static class CameraSelection
{
    public static CameraChoice? SelectInitial(IReadOnlyList<CameraChoice> devices, string? savedId)
    {
        return devices.FirstOrDefault(device => device.IsPreferredDocumentCamera)
            ?? devices.FirstOrDefault(device => device.Id == savedId)
            ?? devices.FirstOrDefault(device => device.IsExternal)
            ?? devices.FirstOrDefault();
    }

    // Prefer a connected HUE, but never fall back from an unplugged camera to a face camera.
    public static CameraChoice? SelectAfterDeviceChange(IReadOnlyList<CameraChoice> devices, string? selectedId)
    {
        return devices.FirstOrDefault(device => device.IsPreferredDocumentCamera) ?? (selectedId is null
            ? SelectInitial(devices, null)
            : devices.FirstOrDefault(device => device.Id == selectedId));
    }
}
