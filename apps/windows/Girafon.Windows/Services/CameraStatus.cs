namespace Girafon.Windows.Services;

public enum CameraState { Starting, Streaming, NoCamera, Disconnected, AccessDenied, Busy, Error }

public sealed record CameraStatus(CameraState State, string? Detail = null);
