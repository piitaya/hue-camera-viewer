using Xunit;

namespace Girafon.Core.Tests;

public sealed class DockGeometryTests
{
    [Theory]
    [InlineData(400, 20, DockEdge.Top)]
    [InlineData(780, 300, DockEdge.Right)]
    [InlineData(400, 580, DockEdge.Bottom)]
    [InlineData(20, 300, DockEdge.Left)]
    public void DragPreviewSelectsTheNearestEdge(double x, double y, DockEdge expected)
        => Assert.Equal(expected, DockGeometry.NearestEdge(x, y, 800, 600));

    [Fact]
    public void TiedEdgesKeepTheCurrentPositionWithoutJitter()
        => Assert.Equal(DockEdge.Left, DockGeometry.NearestEdge(10, 10, 800, 600, DockEdge.Left));

    [Theory]
    [InlineData(20, 21, DockEdge.Top)]
    [InlineData(20, 36, DockEdge.Top)]
    [InlineData(20, 37, DockEdge.Left)]
    public void CornerPreviewChangesEdgeOnlyBeyondTheSnapThreshold(double x, double y, DockEdge expected)
        => Assert.Equal(expected, DockGeometry.NearestEdge(x, y, 800, 600, DockEdge.Top));

    [Fact]
    public void BottomDockRemainsCenteredAndInset()
        => Assert.Equal(new DockPoint(250, 520), DockGeometry.Position(DockEdge.Bottom, 800, 600, 300, 64));

    [Fact]
    public void SmallWindowNeverProducesNegativeOrUnreachableCoordinates()
    {
        Assert.Equal(new DockPoint(0, 0), DockGeometry.Position(DockEdge.Right, 40, 40, 64, 300));
        Assert.Equal(new DockPoint(8, 8), DockGeometry.Clamp(new DockPoint(-100, 1000), 80, 80, 64, 64));
    }
}
