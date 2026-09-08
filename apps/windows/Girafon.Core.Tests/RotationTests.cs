using Xunit;

namespace Girafon.Core.Tests;

public sealed class RotationTests
{
    [Theory]
    [InlineData(0, 2, 3, new byte[] { 1, 2, 3, 4, 5, 6 })]
    [InlineData(1, 3, 2, new byte[] { 5, 3, 1, 6, 4, 2 })]
    [InlineData(2, 2, 3, new byte[] { 6, 5, 4, 3, 2, 1 })]
    [InlineData(3, 3, 2, new byte[] { 2, 4, 6, 1, 3, 5 })]
    [InlineData(-1, 3, 2, new byte[] { 2, 4, 6, 1, 3, 5 })]
    public void EveryRotationPreservesExactPixels(int turns, int width, int height, byte[] expected)
    {
        var input = Enumerable.Range(1, 6).SelectMany(value => new byte[] { (byte)value, 30, 80, 255 }).ToArray();
        var actual = Rotation.RotateBgra(input, 2, 3, turns);
        Assert.Equal((width, height), Rotation.Dimensions(2, 3, turns));
        Assert.Equal(expected.SelectMany(value => new byte[] { value, 30, 80, 255 }).ToArray(), actual);
        Assert.Equal(1, input[0]);
    }

    [Fact]
    public void FourClockwiseTurnsRestoreTheOriginalImage()
    {
        var original = Enumerable.Range(0, 24).Select(value => (byte)value).ToArray();
        var rotated = original;
        var width = 2;
        var height = 3;
        for (var turn = 0; turn < 4; turn++)
        {
            rotated = Rotation.RotateBgra(rotated, width, height, 1);
            (width, height) = (height, width);
        }
        Assert.Equal(original, rotated);
    }

    [Fact]
    public void RotationInputCannotOverflowWhenAdvancing()
    {
        Assert.Equal(0, Rotation.Clockwise(int.MaxValue));
        Assert.Equal(3, Rotation.CounterClockwise(int.MinValue));
        Assert.Throws<ArgumentException>(() => Rotation.RotateBgra([0, 0, 0, 0], 2, 3, 0));
    }

    [Fact]
    public void ZoomStaysWithinItsRangeAndSnapsBackToOne()
    {
        Assert.Equal(1.0, Zoom.Clamp(0.2));
        Assert.Equal(1.0, Zoom.Clamp(1.0005));
        Assert.Equal(4.0, Zoom.Clamp(9));
        Assert.Equal(1.0, Zoom.Clamp(double.NaN));
        Assert.Equal(1.25, Zoom.In(1));
        Assert.Equal(1.0, Zoom.Out(1.25), 6);
        Assert.Equal(4.0, Zoom.In(3.9));
        Assert.False(Zoom.IsZoomed(1));
        Assert.True(Zoom.IsZoomed(1.01));
        Assert.Equal(250, Zoom.Percent(2.5));
    }

    [Fact]
    public void PanStopsAtTheMagnifiedImageEdges()
    {
        Assert.Equal((0.0, 0.0), Zoom.ClampPan(50, -50, 1, 800, 600, 800, 600));
        Assert.Equal((400.0, 300.0), Zoom.ClampPan(1000, 1000, 2, 800, 600, 800, 600));
        Assert.Equal((-400.0, -300.0), Zoom.ClampPan(-1000, -1000, 2, 800, 600, 800, 600));
        // A frame narrower than the viewport cannot pan sideways until it outgrows it.
        Assert.Equal((0.0, 150.0), Zoom.ClampPan(30, 500, 1.5, 400, 600, 800, 600));
    }
}
