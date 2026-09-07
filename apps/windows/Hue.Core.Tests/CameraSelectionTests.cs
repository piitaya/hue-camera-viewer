using Xunit;

namespace Hue.Core.Tests;

public sealed class CameraSelectionTests
{
    private static readonly CameraChoice BuiltIn = new("internal", "Face camera", false);
    private static readonly CameraChoice External = new("usb", "USB camera");
    private static readonly CameraChoice Hue = new("hue", "HUE Pro");

    [Fact]
    public void HueWinsOverRememberedAndBuiltInCameras()
        => Assert.Equal(Hue, CameraSelection.SelectInitial([BuiltIn, External, Hue], BuiltIn.Id));

    [Fact]
    public void RememberedCameraWinsWhenNoHueIsAvailable()
        => Assert.Equal(BuiltIn, CameraSelection.SelectInitial([External, BuiltIn], BuiltIn.Id));

    [Fact]
    public void ExternalCameraWinsWhenRememberedCameraIsMissing()
        => Assert.Equal(External, CameraSelection.SelectInitial([BuiltIn, External], "unplugged"));

    [Fact]
    public void BuiltInCameraIsLastStartupFallback()
        => Assert.Equal(BuiltIn, CameraSelection.SelectInitial([BuiltIn], null));

    [Fact]
    public void UnpluggingSelectedCameraNeverSwitchesToAnotherCamera()
        => Assert.Null(CameraSelection.SelectAfterDeviceChange([BuiltIn, External], Hue.Id));

    [Fact]
    public void ReconnectingSameCameraRestoresThatCamera()
        => Assert.Equal(External, CameraSelection.SelectAfterDeviceChange([BuiltIn, External], External.Id));

    [Fact]
    public void ConnectingHuePromotesItOverTheBuiltInCamera()
        => Assert.Equal(Hue, CameraSelection.SelectAfterDeviceChange([BuiltIn, Hue], BuiltIn.Id));

    [Fact]
    public void AConnectedHueCanReplaceAnUnpluggedExternalCamera()
        => Assert.Equal(Hue, CameraSelection.SelectAfterDeviceChange([BuiltIn, Hue], External.Id));

    [Fact]
    public void StartingWithoutDevicesAllowsTheFirstConnectedCamera()
    {
        Assert.Null(CameraSelection.SelectInitial([], null));
        Assert.Equal(Hue, CameraSelection.SelectAfterDeviceChange([BuiltIn, Hue], null));
    }
}
