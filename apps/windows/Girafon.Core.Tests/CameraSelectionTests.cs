using Xunit;

namespace Girafon.Core.Tests;

public sealed class CameraSelectionTests
{
    private static readonly CameraChoice BuiltIn = new("internal", "Face camera", false);
    private static readonly CameraChoice External = new("usb", "USB camera");
    private static readonly CameraChoice DocumentCamera = new("document-camera", "HUE Pro");

    [Fact]
    public void DocumentCameraWinsOverRememberedAndBuiltInCameras()
        => Assert.Equal(DocumentCamera, CameraSelection.SelectInitial([BuiltIn, External, DocumentCamera], BuiltIn.Id));

    [Fact]
    public void RememberedCameraWinsWhenNoDocumentCameraIsAvailable()
        => Assert.Equal(BuiltIn, CameraSelection.SelectInitial([External, BuiltIn], BuiltIn.Id));

    [Fact]
    public void ExternalCameraWinsWhenRememberedCameraIsMissing()
        => Assert.Equal(External, CameraSelection.SelectInitial([BuiltIn, External], "unplugged"));

    [Fact]
    public void BuiltInCameraIsLastStartupFallback()
        => Assert.Equal(BuiltIn, CameraSelection.SelectInitial([BuiltIn], null));

    [Fact]
    public void UnpluggingSelectedCameraNeverSwitchesToAnotherCamera()
        => Assert.Null(CameraSelection.SelectAfterDeviceChange([BuiltIn, External], DocumentCamera.Id));

    [Fact]
    public void ReconnectingSameCameraRestoresThatCamera()
        => Assert.Equal(External, CameraSelection.SelectAfterDeviceChange([BuiltIn, External], External.Id));

    [Fact]
    public void ConnectingDocumentCameraPromotesItOverTheBuiltInCamera()
        => Assert.Equal(DocumentCamera, CameraSelection.SelectAfterDeviceChange([BuiltIn, DocumentCamera], BuiltIn.Id));

    [Fact]
    public void AConnectedDocumentCameraCanReplaceAnUnpluggedExternalCamera()
        => Assert.Equal(DocumentCamera, CameraSelection.SelectAfterDeviceChange([BuiltIn, DocumentCamera], External.Id));

    [Fact]
    public void StartingWithoutDevicesAllowsTheFirstConnectedCamera()
    {
        Assert.Null(CameraSelection.SelectInitial([], null));
        Assert.Equal(DocumentCamera, CameraSelection.SelectAfterDeviceChange([BuiltIn, DocumentCamera], null));
    }
}
