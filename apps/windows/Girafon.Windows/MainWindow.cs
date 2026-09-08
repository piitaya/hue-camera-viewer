using System.Diagnostics;
using System.Numerics;
using System.Text.Json;
using Girafon.Core;
using Girafon.Windows.Services;
using Microsoft.UI;
using Microsoft.UI.Composition;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Automation;
using Microsoft.UI.Xaml.Automation.Peers;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Hosting;
using Microsoft.UI.Xaml.Input;
using Microsoft.UI.Xaml.Markup;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Media.Imaging;
using Microsoft.UI.Xaml.Shapes;
using Windows.Foundation;
using Windows.Graphics.Imaging;
using Windows.Storage;
using Windows.Storage.Streams;
using Windows.System;
using Windows.UI.ViewManagement;
using Path = System.IO.Path;

namespace Girafon.Windows;

internal sealed class MainWindow : Window
{
    private static class ThemeColors
    {
        public static readonly global::Windows.UI.Color Terracotta = ColorHelper.FromArgb(255, 201, 93, 53);
    }

    private readonly LaunchOptions _options;
    private readonly CameraService _camera = new();
    private readonly SettingsStore _settingsStore = new();
    private AppSettings _settings;
    private readonly Grid _root = new() { Background = new SolidColorBrush(Colors.Black) };
    private readonly Image _preview = new() { Stretch = Stretch.Fill, RenderTransformOrigin = new Point(0.5, 0.5) };
    private readonly RotateTransform _rotation = new();
    private readonly SoftwareBitmapSource _source = new();
    private readonly TextBlock _status = new()
    {
        Foreground = new SolidColorBrush(Colors.White), FontSize = 18, TextWrapping = TextWrapping.Wrap,
        TextAlignment = TextAlignment.Center, MaxWidth = 460
    };
    private readonly StackPanel _statusPanel = new()
    {
        Spacing = 18, HorizontalAlignment = HorizontalAlignment.Center,
        VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(30)
    };
    private readonly Button _permissions = new() { HorizontalAlignment = HorizontalAlignment.Center };
    private readonly Border _toast = new()
    {
        Background = new SolidColorBrush(ColorHelper.FromArgb(235, 30, 33, 34)),
        CornerRadius = new CornerRadius(12), Padding = new Thickness(16, 10, 16, 10),
        HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Top,
        Margin = new Thickness(24), Visibility = Visibility.Collapsed, IsHitTestVisible = false
    };
    private readonly TextBlock _toastText = new()
    {
        Foreground = new SolidColorBrush(Colors.White), TextWrapping = TextWrapping.Wrap, MaxWidth = 460
    };
    private readonly Canvas _overlay = new();
    private readonly Border _dock = new()
    {
        CornerRadius = new CornerRadius(31), BorderThickness = new Thickness(1)
    };
    private readonly Border _snapPreview = new()
    {
        Background = new SolidColorBrush(ThemeColors.Terracotta) { Opacity = 45.0 / 255 },
        BorderBrush = new SolidColorBrush(ThemeColors.Terracotta) { Opacity = 220.0 / 255 },
        BorderThickness = new Thickness(2), CornerRadius = new CornerRadius(30),
        IsHitTestVisible = false, Visibility = Visibility.Collapsed
    };
    private readonly Grid _dockContent = new();
    private readonly StackPanel _dockStack = new()
    {
        Spacing = 6, HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center
    };
    private readonly StackPanel _controls = new() { Spacing = 6 };
    private readonly TranslateTransform _dockPosition = new();
    private readonly List<Shape> _themeShapes = new();
    private readonly Button _grip;
    private readonly Button _cameraButton;
    private readonly Button _rotateLeft;
    private readonly Button _rotateRight;
    private readonly Button _capture;
    private readonly Button _collapse;
    private readonly Button _expand;
    private readonly RotateTransform _gripRotation = new() { CenterX = 12, CenterY = 12 };
    private readonly RotateTransform _chevronRotation = new() { CenterX = 12, CenterY = 12 };
    private readonly RotateTransform _expandChevronRotation = new() { CenterX = 12, CenterY = 12 };
    private readonly UISettings _uiSettings = new();
    private readonly Stopwatch _motionClock = Stopwatch.StartNew();
    private CompositionRoundedRectangleGeometry? _dockClipGeometry;
    private CompositionGeometricClip? _dockClip;
    private DockPresentation _dockPresentation;
    private DockPresentation _snapPresentation;
    private DockMotion? _dockMotion;
    private DockMotion? _snapMotion;
    private bool _renderingMotion;
    private int _renderedMotionFrames;
    private bool _forceDockMotionForTest;
    private readonly TaskCompletionSource<bool> _firstFrame = new(TaskCreationOptions.RunContinuationsAsynchronously);
    private readonly object _frameGate = new();
    private SoftwareBitmap? _pendingFrame;
    private bool _frameScheduled;
    private bool _closing;
    private bool _initialized;
    private bool _capturing;
    private bool _streaming;
    private bool _hasPresentedFrame;
    private int _renderEpoch;
    private bool _dragging;
    private bool _dragMoved;
    private Point _dragStart;
    private Point _dragOffset;
    private DockEdge _candidateEdge;
    private int _frameWidth = 640;
    private int _frameHeight = 480;
    private CancellationTokenSource? _toastLifetime;

    private bool DockAnimationsEnabled => (_options.SmokeTest && _forceDockMotionForTest) || _uiSettings.AnimationsEnabled;

    public MainWindow(LaunchOptions options)
    {
        _options = options;
        _settings = options.Demo ? new AppSettings() : _settingsStore.Load();
        Title = "Girafon";
        AppWindow.Resize(new global::Windows.Graphics.SizeInt32(1120, 780));
        string icon = Path.Combine(AppContext.BaseDirectory, "Assets", "Girafon.ico");
        if (File.Exists(icon)) AppWindow.SetIcon(icon);

        _preview.Source = _source;
        _preview.RenderTransform = _rotation;
        _root.Children.Add(_preview);
        _permissions.Content = Strings.Get("Open camera settings");
        _permissions.Click += async (_, _) =>
        {
            try { await Launcher.LaunchUriAsync(new Uri("ms-settings:privacy-webcam")); }
            catch (Exception) { ShowToast("Allow desktop apps to access your camera in Windows Settings."); }
        };
        _statusPanel.Children.Add(_status);
        _statusPanel.Children.Add(_permissions);
        _root.Children.Add(_statusPanel);
        _root.Children.Add(_overlay);
        _toast.Child = _toastText;
        _root.Children.Add(_toast);

        _grip = MakeButton("Move controls", MakeGlyph(DockIcons.Grip, rotation: _gripRotation), new DockHandleButton());
        _grip.Click += (_, _) => ShowDockMenu();
        _grip.AddHandler(UIElement.PointerPressedEvent, new PointerEventHandler(GripPressed), true);
        _grip.AddHandler(UIElement.PointerMovedEvent, new PointerEventHandler(GripMoved), true);
        _grip.AddHandler(UIElement.PointerReleasedEvent, new PointerEventHandler(GripReleased), true);
        _grip.PointerCanceled += (_, _) => FinishDrag(false);
        _grip.PointerCaptureLost += (_, _) => FinishDrag(false);

        _cameraButton = MakeButton("Choose camera", MakeGlyph(DockIcons.Source));
        _cameraButton.Click += (_, _) => ShowCameraMenu();
        _rotateLeft = MakeButton("Rotate left", MakeGlyph(DockIcons.RotateLeft));
        _rotateLeft.Click += (_, _) => Rotate(-1);
        _rotateRight = MakeButton("Rotate right", MakeGlyph(DockIcons.RotateRight));
        _rotateRight.Click += (_, _) => Rotate(1);
        _capture = MakeButton("Capture image", MakeGlyph(DockIcons.Capture));
        _capture.Click += async (_, _) => await CaptureAsync();
        _collapse = MakeButton("Hide controls", MakeGlyph(DockIcons.ChevronRight, 15, _chevronRotation));
        _collapse.Click += (_, _) => ToggleDock();
        _expand = MakeButton("Show controls", MakeGlyph(DockIcons.ChevronRight, 15, _expandChevronRotation));
        _expand.MinWidth = _expand.MinHeight = 0;
        _expand.HorizontalAlignment = HorizontalAlignment.Center;
        _expand.VerticalAlignment = VerticalAlignment.Center;
        _expand.Click += (_, _) => ToggleDock();

        foreach (Button control in new[] { _cameraButton, _rotateLeft, _rotateRight, _capture }) _controls.Children.Add(control);
        _dockStack.Children.Add(_grip);
        _dockStack.Children.Add(_controls);
        _dockStack.Children.Add(_collapse);
        _dockContent.Children.Add(_dockStack);
        _dockContent.Children.Add(_expand);
        _dock.Child = _dockContent;
        _dock.RenderTransform = _dockPosition;
        _overlay.Children.Add(_snapPreview);
        _overlay.Children.Add(_dock);

        _root.SizeChanged += (_, _) =>
        {
            LayoutPreview();
            if (_dragging) FinishDrag(false);
            HideSnapPreview();
            LayoutDock(false);
        };
        _root.ActualThemeChanged += (_, _) => ApplyTheme();
        _root.Loaded += async (_, _) => await InitializeAsync();
        Closed += async (_, _) => await CloseAsync();
        Content = _root;
        ApplyTheme();
        ApplyStatus(new CameraStatus(CameraState.Starting));
        _camera.FrameReady += FrameReady;
        _camera.StatusChanged += status => DispatcherQueue.TryEnqueue(() => { if (!_closing) ApplyStatus(status); });
        _camera.DevicesChanged += _ => DispatcherQueue.TryEnqueue(() => { if (!_closing) UpdateCameraLabel(); });
    }

    private async Task InitializeAsync()
    {
        if (_initialized) return;
        _initialized = true;
        LayoutDock(false);
        try
        {
            await _camera.InitializeAsync(_settings.CameraId, _options.Demo);
            if (_options.SmokeTest) await RunSmokeTestAsync();
        }
        catch (Exception exception)
        {
            if (_options.SmokeTest) await FinishSmokeTestAsync(false, exception.ToString(), Array.Empty<string>());
            else ApplyStatus(new CameraStatus(CameraState.Error));
        }
    }

    private void FrameReady(SoftwareBitmap frame)
    {
        lock (_frameGate)
        {
            if (_closing) { frame.Dispose(); return; }
            _pendingFrame?.Dispose();
            _pendingFrame = frame;
            if (_frameScheduled) return;
            _frameScheduled = true;
            if (!DispatcherQueue.TryEnqueue(async () => await RenderFramesAsync()))
            {
                _pendingFrame.Dispose();
                _pendingFrame = null;
                _frameScheduled = false;
            }
        }
    }

    private async Task RenderFramesAsync()
    {
        while (true)
        {
            SoftwareBitmap? frame;
            lock (_frameGate)
            {
                frame = _pendingFrame;
                _pendingFrame = null;
                if (frame is null) { _frameScheduled = false; return; }
            }
            using (frame)
            {
                if (_closing || !_camera.HasFrame) continue;
                try
                {
                    int epoch = _renderEpoch;
                    await _source.SetBitmapAsync(frame);
                    if (_closing || epoch != _renderEpoch) continue;
                    if (_frameWidth != frame.PixelWidth || _frameHeight != frame.PixelHeight)
                    {
                        _frameWidth = frame.PixelWidth;
                        _frameHeight = frame.PixelHeight;
                        LayoutPreview();
                    }
                    _hasPresentedFrame = true;
                    RefreshFrameVisibility();
                    _firstFrame.TrySetResult(true);
                }
                catch (Exception exception)
                {
                    if (_options.SmokeTest) _firstFrame.TrySetException(exception);
                    ApplyStatus(new CameraStatus(CameraState.Error));
                }
            }
        }
    }

    private void LayoutPreview()
    {
        int turns = Rotation.Normalize(_settings.RotationQuarterTurns);
        bool sideways = turns % 2 != 0;
        double width = sideways ? _frameHeight : _frameWidth;
        double height = sideways ? _frameWidth : _frameHeight;
        double scale = Math.Min(_root.ActualWidth / width, _root.ActualHeight / height);
        _preview.Width = Math.Max(1, _frameWidth * scale);
        _preview.Height = Math.Max(1, _frameHeight * scale);
        _rotation.Angle = turns * 90;
    }

    private void Rotate(int direction)
    {
        _settings = _settings with { RotationQuarterTurns = Rotation.Normalize(_settings.RotationQuarterTurns + direction) };
        LayoutPreview();
        SaveSettings();
    }

    private async Task CaptureAsync()
    {
        if (_capturing || !_camera.HasFrame) return;
        _capturing = true;
        _capture.IsEnabled = false;
        int turns = _settings.RotationQuarterTurns;
        try
        {
            await _camera.CaptureAsync(turns, _options.CaptureDirectory);
            ShowToast(_options.CaptureDirectory is null ? "Image saved to Desktop" : "Image saved");
        }
        catch (Exception) { ShowToast("Could not save the image. Check the folder permissions and available space."); }
        finally { _capturing = false; RefreshFrameVisibility(); }
    }

    private void ApplyStatus(CameraStatus status)
    {
        _streaming = status.State == CameraState.Streaming;
        if (!_streaming)
        {
            _renderEpoch++;
            _hasPresentedFrame = false;
            lock (_frameGate)
            {
                _pendingFrame?.Dispose();
                _pendingFrame = null;
            }
        }
        _status.Text = Strings.Get(status.State switch
        {
            CameraState.Starting or CameraState.Streaming => "Starting camera…",
            CameraState.NoCamera => "Connect a camera to begin.",
            CameraState.Disconnected => "Camera disconnected. Reconnect it or choose another camera.",
            CameraState.AccessDenied => "Allow desktop apps to access your camera in Windows Settings.",
            CameraState.Busy => "Camera unavailable. Close other camera apps and try again.",
            _ => "Could not start the camera. Choose a camera to try again."
        });
        _permissions.Visibility = status.State == CameraState.AccessDenied ? Visibility.Visible : Visibility.Collapsed;
        RefreshFrameVisibility();
        if ((status.State is CameraState.Starting or CameraState.Streaming) && _camera.SelectedCameraId is not null)
        {
            _settings = _settings with { CameraId = _camera.SelectedCameraId };
            SaveSettings();
        }
        UpdateCameraLabel();
    }

    private void RefreshFrameVisibility()
    {
        bool ready = _streaming && _hasPresentedFrame && _camera.HasFrame;
        _statusPanel.Visibility = ready ? Visibility.Collapsed : Visibility.Visible;
        _preview.Opacity = ready ? 1 : 0;
        _capture.IsEnabled = ready && !_capturing;
        _rotateLeft.IsEnabled = ready;
        _rotateRight.IsEnabled = ready;
    }

    private void UpdateCameraLabel()
    {
        string? name = _camera.Devices.FirstOrDefault(device => device.Id == _camera.SelectedCameraId)?.Name;
        ToolTipService.SetToolTip(_cameraButton, name is null ? Strings.Get("Choose camera") : $"{Strings.Get("Choose camera")} · {name}");
    }

    private void ShowCameraMenu()
    {
        MenuFlyout menu = new();
        foreach (CameraChoice device in _camera.Devices)
        {
            ToggleMenuFlyoutItem item = new()
            {
                Text = device.Id == "demo" ? Strings.Get("Demo") : device.Name,
                IsChecked = device.Id == _camera.SelectedCameraId
            };
            item.Click += async (_, _) =>
            {
                try { await _camera.SelectCameraAsync(device.Id); }
                catch (Exception) { ApplyStatus(new CameraStatus(CameraState.Error)); }
            };
            menu.Items.Add(item);
        }
        if (menu.Items.Count == 0) menu.Items.Add(new MenuFlyoutItem { Text = Strings.Get("No cameras found"), IsEnabled = false });
        menu.ShowAt(_cameraButton);
    }

    private void ShowDockMenu()
    {
        MenuFlyout menu = new();
        foreach (DockEdge edge in Enum.GetValues<DockEdge>())
        {
            ToggleMenuFlyoutItem item = new() { Text = Strings.Get(edge.ToString()), IsChecked = _settings.DockEdge == edge };
            item.Click += (_, _) => { _settings = _settings with { DockEdge = edge }; LayoutDock(true, dropping: true); SaveSettings(); };
            menu.Items.Add(item);
        }
        menu.ShowAt(_grip);
    }

    private void ToggleDock()
    {
        if (_dragging) FinishDrag(false);
        bool hadFocus = _collapse.FocusState != FocusState.Unfocused || _expand.FocusState != FocusState.Unfocused;
        _settings = _settings with { IsDockCollapsed = !_settings.IsDockCollapsed };
        LayoutDock(true);
        if (hadFocus) (_settings.IsDockCollapsed ? _expand : _collapse).Focus(FocusState.Programmatic);
        SaveSettings();
    }

    private static (double Width, double Height) DockSize(DockEdge edge, bool collapsed)
    {
        bool horizontal = edge is DockEdge.Top or DockEdge.Bottom;
        return collapsed ? (horizontal ? (46, 26) : (26, 46)) : (horizontal ? (312, 62) : (62, 312));
    }

    private DockPresentation AnchoredDock(DockEdge edge, bool collapsed)
    {
        var size = DockSize(edge, collapsed);
        DockPoint position = DockGeometry.Position(edge, _root.ActualWidth, _root.ActualHeight,
            size.Width, size.Height, collapsed ? 8 : 16);
        return new DockPresentation(edge, position.X, position.Y, size.Width, size.Height,
            collapsed ? 0 : 1, collapsed ? 1 : 0);
    }

    private void LayoutDock(bool animate, bool dropping = false)
    {
        if (_closing) return;
        if (_root.ActualWidth <= 0 || _root.ActualHeight <= 0)
        {
            _dockMotion = null;
            UpdateMotionSubscription();
            return;
        }
        DockPresentation target = AnchoredDock(_settings.DockEdge, _settings.IsDockCollapsed);
        SetDockInteraction();
        if (animate && DockAnimationsEnabled && _dockPresentation.Width > 0)
        {
            _dockMotion = new DockMotion(_dockPresentation, target, _motionClock.Elapsed.TotalSeconds,
                dropping ? 0.42 : 0.36, dropping ? 0.82 : 0.88);
        }
        else
        {
            _dockMotion = null;
            ApplyDockPresentation(target);
        }
        UpdateMotionSubscription();
    }

    private void SetDockInteraction()
    {
        bool expanded = !_settings.IsDockCollapsed;
        _dockStack.IsHitTestVisible = expanded;
        foreach (Button button in new[] { _grip, _cameraButton, _rotateLeft, _rotateRight, _capture, _collapse })
        {
            button.IsTabStop = expanded;
            AutomationProperties.SetAccessibilityView(button, expanded ? AccessibilityView.Control : AccessibilityView.Raw);
        }
        _expand.IsHitTestVisible = !expanded;
        _expand.IsTabStop = !expanded;
        AutomationProperties.SetAccessibilityView(_expand, expanded ? AccessibilityView.Raw : AccessibilityView.Control);
    }

    private void ApplyDockPresentation(DockPresentation presentation)
    {
        DockPoint clamped = DockGeometry.Clamp(new DockPoint(presentation.X, presentation.Y),
            _root.ActualWidth, _root.ActualHeight, presentation.Width, presentation.Height, 0);
        _dockPresentation = presentation with { X = clamped.X, Y = clamped.Y };
        _dock.Width = presentation.Width;
        _dock.Height = presentation.Height;
        _dock.CornerRadius = new CornerRadius(Math.Min(presentation.Width, presentation.Height) / 2);
        _dockPosition.X = clamped.X;
        _dockPosition.Y = clamped.Y;

        bool horizontal = presentation.Edge is DockEdge.Top or DockEdge.Bottom;
        _gripRotation.Angle = horizontal ? 0 : 90;
        _dockStack.Orientation = _controls.Orientation = horizontal ? Orientation.Horizontal : Orientation.Vertical;
        _dockStack.Width = horizontal ? 294 : 44;
        _dockStack.Height = horizontal ? 44 : 294;
        _dockStack.Opacity = presentation.ExpandedOpacity;
        _expand.Width = horizontal ? 44 : 24;
        _expand.Height = horizontal ? 24 : 44;
        _expand.Opacity = presentation.CollapsedOpacity;
        _chevronRotation.Angle = presentation.Edge switch
        {
            DockEdge.Right => 0, DockEdge.Bottom => 90, DockEdge.Left => 180, _ => 270
        };
        _expandChevronRotation.Angle = _chevronRotation.Angle + 180;

        // Keep both sets of controls and the acrylic alive. The compositor clip
        // follows the capsule on the same frame, even while its contents reflow.
        if (_dockClipGeometry is null)
        {
            Visual visual = ElementCompositionPreview.GetElementVisual(_dockContent);
            _dockClipGeometry = visual.Compositor.CreateRoundedRectangleGeometry();
            _dockClip = visual.Compositor.CreateGeometricClip(_dockClipGeometry);
            visual.Clip = _dockClip;
        }
        float width = (float)Math.Max(0, presentation.Width - 2);
        float height = (float)Math.Max(0, presentation.Height - 2);
        _dockContent.Width = width;
        _dockContent.Height = height;
        _dockClipGeometry.Size = new Vector2(width, height);
        _dockClipGeometry.CornerRadius = new Vector2(Math.Min(width, height) / 2);
    }

    private void MoveDock(double x, double y)
    {
        _dockMotion = null;
        ApplyDockPresentation(_dockPresentation with { X = x, Y = y });
        UpdateMotionSubscription();
    }

    private void ShowSnapPreview(DockEdge edge)
    {
        DockPresentation target = AnchoredDock(edge, false);
        bool visible = _snapPreview.Visibility == Visibility.Visible;
        _snapPreview.Visibility = Visibility.Visible;
        if (visible && (_snapMotion?.Target.Edge ?? _snapPresentation.Edge) == edge) return;
        if (visible && DockAnimationsEnabled)
            _snapMotion = new DockMotion(_snapPresentation, target, _motionClock.Elapsed.TotalSeconds, 0.30, 0.82);
        else
        {
            _snapMotion = null;
            ApplySnapPresentation(target);
        }
        UpdateMotionSubscription();
    }

    private void ApplySnapPresentation(DockPresentation presentation)
    {
        DockPoint point = DockGeometry.Clamp(new DockPoint(presentation.X, presentation.Y),
            _root.ActualWidth, _root.ActualHeight, presentation.Width, presentation.Height, 0);
        _snapPresentation = presentation with { X = point.X, Y = point.Y };
        _snapPreview.Width = presentation.Width;
        _snapPreview.Height = presentation.Height;
        _snapPreview.CornerRadius = new CornerRadius(Math.Min(presentation.Width, presentation.Height) / 2);
        Canvas.SetLeft(_snapPreview, point.X);
        Canvas.SetTop(_snapPreview, point.Y);
    }

    private void HideSnapPreview()
    {
        _snapMotion = null;
        _snapPreview.Visibility = Visibility.Collapsed;
        UpdateMotionSubscription();
    }

    private void RenderDockMotion(object? sender, object args)
    {
        _renderedMotionFrames++;
        double now = _motionClock.Elapsed.TotalSeconds;
        bool finish = !DockAnimationsEnabled;
        if (_dockMotion is { } dockMotion)
        {
            ApplyDockPresentation(finish ? dockMotion.Target : dockMotion.Sample(now));
            if (finish || dockMotion.IsComplete(now)) _dockMotion = null;
        }
        if (_snapMotion is { } snapMotion)
        {
            ApplySnapPresentation(finish ? snapMotion.Target : snapMotion.Sample(now));
            if (finish || snapMotion.IsComplete(now)) _snapMotion = null;
        }
        UpdateMotionSubscription();
    }

    private void UpdateMotionSubscription()
    {
        bool needed = !_closing && (_dockMotion is not null || _snapMotion is not null);
        if (_renderingMotion == needed) return;
        _renderingMotion = needed;
        if (needed) CompositionTarget.Rendering += RenderDockMotion;
        else CompositionTarget.Rendering -= RenderDockMotion;
    }

    private void GripPressed(object sender, PointerRoutedEventArgs args)
    {
        var point = args.GetCurrentPoint(_root);
        if (_settings.IsDockCollapsed || !point.Properties.IsLeftButtonPressed) return;
        // Freeze the displayed presentation, so grabbing a moving dock never jumps.
        _dockMotion = null;
        UpdateMotionSubscription();
        _dragStart = point.Position;
        _dragOffset = new Point(point.Position.X - _dockPosition.X, point.Position.Y - _dockPosition.Y);
        _candidateEdge = _settings.DockEdge;
        _dragging = true;
        _dragMoved = false;
        _grip.CapturePointer(args.Pointer);
    }

    private void GripMoved(object sender, PointerRoutedEventArgs args)
    {
        if (!_dragging) return;
        Point point = args.GetCurrentPoint(_root).Position;
        if (!_dragMoved && Math.Abs(point.X - _dragStart.X) + Math.Abs(point.Y - _dragStart.Y) < 5) return;
        _dragMoved = true;
        args.Handled = true;
        DockPoint current = DockGeometry.Clamp(new DockPoint(point.X - _dragOffset.X, point.Y - _dragOffset.Y),
            _root.ActualWidth, _root.ActualHeight, _dock.Width, _dock.Height);
        MoveDock(current.X, current.Y);
        _candidateEdge = DockGeometry.NearestEdge(current.X + _dock.Width / 2, current.Y + _dock.Height / 2,
            _root.ActualWidth, _root.ActualHeight, _candidateEdge);
        ShowSnapPreview(_candidateEdge);
    }

    private void GripReleased(object sender, PointerRoutedEventArgs args)
    {
        if (!_dragging) return;
        bool moved = _dragMoved;
        FinishDrag(true);
        args.Handled = true;
        if (!moved) ShowDockMenu();
    }

    private void FinishDrag(bool commit)
    {
        if (!_dragging) return;
        _dragging = false;
        _grip.ReleasePointerCaptures();
        HideSnapPreview();
        if (commit && _dragMoved)
        {
            _settings = _settings with { DockEdge = _candidateEdge };
            SaveSettings();
        }
        LayoutDock(_dragMoved, dropping: true);
    }

    private void ApplyTheme()
    {
        bool dark = _root.ActualTheme == ElementTheme.Dark;
        var tint = dark ? ColorHelper.FromArgb(255, 35, 38, 40) : ColorHelper.FromArgb(255, 246, 247, 245);
        _dock.Background = new AcrylicBrush { TintColor = tint, TintOpacity = 0.88, FallbackColor = tint };
        _dock.BorderBrush = new SolidColorBrush(dark ? ColorHelper.FromArgb(255, 85, 90, 91) : ColorHelper.FromArgb(255, 203, 208, 207));
        Brush foreground = new SolidColorBrush(dark ? ColorHelper.FromArgb(255, 241, 244, 243) : ColorHelper.FromArgb(255, 35, 45, 43));
        foreach (Shape shape in _themeShapes) shape.Stroke = foreground;
    }

    private Viewbox MakeGlyph(string data, double size = 21, RotateTransform? rotation = null)
    {
        Canvas canvas = new() { Width = 24, Height = 24 };
        if (rotation is not null) canvas.RenderTransform = rotation;
        var path = (Microsoft.UI.Xaml.Shapes.Path)XamlReader.Load($"<Path xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation' Data='{data}' StrokeThickness='2' StrokeLineJoin='Round' StrokeStartLineCap='Round' StrokeEndLineCap='Round' />");
        _themeShapes.Add(path);
        canvas.Children.Add(path);
        return new Viewbox { Width = size, Height = size, Child = canvas };
    }

    private static Button MakeButton(string label, UIElement glyph, Button? button = null)
    {
        button ??= new Button();
        button.Width = 44;
        button.Height = 44;
        button.Padding = new Thickness(0);
        button.Content = glyph;
        button.CornerRadius = new CornerRadius(22);
        button.BorderThickness = new Thickness(0);
        button.Background = new SolidColorBrush(Colors.Transparent);
        button.HorizontalContentAlignment = HorizontalAlignment.Center;
        button.VerticalContentAlignment = VerticalAlignment.Center;
        ToolTipService.SetToolTip(button, Strings.Get(label));
        AutomationProperties.SetName(button, Strings.Get(label));
        return button;
    }

    private void SaveSettings()
    {
        if (_options.Demo) return;
        try { _settingsStore.Save(_settings); }
        catch (Exception) { ShowToast("Settings could not be saved."); }
    }

    private async void ShowToast(string text)
    {
        _toastLifetime?.Cancel();
        _toastLifetime?.Dispose();
        _toastLifetime = new CancellationTokenSource();
        CancellationToken token = _toastLifetime.Token;
        _toastText.Text = Strings.Get(text);
        _toast.Visibility = Visibility.Visible;
        try { await Task.Delay(3500, token); _toast.Visibility = Visibility.Collapsed; }
        catch (OperationCanceledException) { }
    }

    private async Task CloseAsync()
    {
        lock (_frameGate)
        {
            _closing = true;
            _pendingFrame?.Dispose();
            _pendingFrame = null;
        }
        _toastLifetime?.Cancel();
        _dockMotion = null;
        _snapMotion = null;
        UpdateMotionSubscription();
        _grip.ReleasePointerCaptures();
        _dockClip?.Dispose();
        _dockClipGeometry?.Dispose();
        _camera.FrameReady -= FrameReady;
        await _camera.DisposeAsync();
    }

    private async Task RunSmokeTestAsync()
    {
        await _firstFrame.Task.WaitAsync(TimeSpan.FromSeconds(15));
        List<string> captures = new();
        for (int turns = 0; turns < 4; turns++)
        {
            _settings = _settings with { RotationQuarterTurns = turns };
            LayoutPreview();
            string capture = await _camera.CaptureAsync(turns, _options.CaptureDirectory);
            StorageFile file = await StorageFile.GetFileFromPathAsync(capture);
            using IRandomAccessStream stream = await file.OpenAsync(FileAccessMode.Read);
            BitmapDecoder decoder = await BitmapDecoder.CreateAsync(stream);
            uint expectedWidth = (uint)(turns % 2 == 0 ? _frameWidth : _frameHeight);
            uint expectedHeight = (uint)(turns % 2 == 0 ? _frameHeight : _frameWidth);
            if (decoder.PixelWidth != expectedWidth || decoder.PixelHeight != expectedHeight)
                throw new InvalidOperationException($"Capture {turns} has incorrect dimensions.");
            captures.Add(capture);
        }
        await CheckDockMotionAsync();
        _settings = _settings with { RotationQuarterTurns = 0, DockEdge = DockEdge.Right, IsDockCollapsed = false };
        _root.RequestedTheme = ElementTheme.Dark;
        LayoutPreview();
        LayoutDock(false);
        await SaveScreenshotAsync("ui-right-dark.png");
        _settings = _settings with { DockEdge = DockEdge.Bottom };
        _root.RequestedTheme = ElementTheme.Light;
        LayoutDock(false);
        await SaveScreenshotAsync("ui-bottom-light.png");
        _settings = _settings with { DockEdge = DockEdge.Top, IsDockCollapsed = true };
        LayoutDock(false);
        await SaveScreenshotAsync("ui-top-collapsed.png");
        _settings = _settings with { DockEdge = DockEdge.Left, IsDockCollapsed = false };
        LayoutDock(false);
        await SaveScreenshotAsync("ui-left-light.png");
        await FinishSmokeTestAsync(true, null, captures);
    }

    private async Task CheckDockMotionAsync()
    {
        // Exercise the user's actual preference first, including the instant
        // accessibility path on Windows Server CI where animations are disabled.
        _settings = _settings with { DockEdge = DockEdge.Right, IsDockCollapsed = false };
        LayoutDock(false);
        ToggleDock();
        if (!_uiSettings.AnimationsEnabled && (_dockMotion is not null || _renderingMotion))
            throw new InvalidOperationException("The dock ignored the system animation preference.");
        await WaitForDockMotionAsync();
        AssertDockPresentation();

        // Force only this development check to exercise actual rendering frames.
        // This changes no system setting and cannot affect a normal application run.
        int initialFrameCount = _renderedMotionFrames;
        _forceDockMotionForTest = true;
        try
        {
            Brush surface = _dock.Background;
            foreach (DockEdge edge in Enum.GetValues<DockEdge>())
            {
                _settings = _settings with { DockEdge = edge, IsDockCollapsed = false };
                LayoutDock(false);
                ToggleDock();
                await WaitForDockMotionAsync();
                AssertDockPresentation();
                if (_grip.IsTabStop || _dockStack.IsHitTestVisible || !_expand.IsTabStop || _dockStack.Opacity != 0)
                    throw new InvalidOperationException("Collapsed controls remain visible or interactive.");
                if (AutomationProperties.GetAccessibilityView(_grip) != AccessibilityView.Raw)
                    throw new InvalidOperationException("The hidden drag grip remains in the accessibility control view.");
                ToggleDock();
                await WaitForDockMotionAsync();
                AssertDockPresentation();
            }

            // Reverse an in-flight fold from its displayed dimensions, not its old target.
            ToggleDock();
            await Task.Delay(35);
            DockPresentation before = _dockPresentation;
            ToggleDock();
            if (DockAnimationsEnabled && _dockPresentation != before)
                throw new InvalidOperationException("Retargeting a dock animation jumps its presentation.");
            await Task.Delay(35);
            ToggleDock();
            await WaitForDockMotionAsync();
            AssertDockPresentation();

            _settings = _settings with { IsDockCollapsed = false };
            LayoutDock(false);
            ShowSnapPreview(DockEdge.Top);
            ShowSnapPreview(DockEdge.Right);
            await WaitForDockMotionAsync();
            DockPresentation target = AnchoredDock(DockEdge.Right, false);
            if (Math.Abs(_snapPresentation.X - target.X) > 0.01 || Math.Abs(_snapPresentation.Width - target.Width) > 0.01)
                throw new InvalidOperationException("The animated snap preview did not reach its edge.");
            HideSnapPreview();

            _settings = _settings with { DockEdge = DockEdge.Bottom };
            LayoutDock(true, dropping: true);
            await Task.Delay(35);
            // Window resizing takes this same immediate layout path and cancels motion.
            LayoutDock(false);
            AssertDockPresentation();
            if (_dockMotion is not null || _snapMotion is not null || _renderingMotion)
                throw new InvalidOperationException("Dock motion kept running after cancellation.");
            if (!ReferenceEquals(surface, _dock.Background))
                throw new InvalidOperationException("Dock transitions recreated their acrylic surface.");
            if (_renderedMotionFrames <= initialFrameCount)
                throw new InvalidOperationException("The dock checks did not render any animation frames.");
        }
        finally
        {
            _forceDockMotionForTest = false;
            HideSnapPreview();
            LayoutDock(false);
        }
    }

    private async Task WaitForDockMotionAsync()
    {
        Stopwatch timeout = Stopwatch.StartNew();
        while (_dockMotion is not null || _snapMotion is not null)
        {
            if (timeout.Elapsed > TimeSpan.FromSeconds(3))
                throw new TimeoutException("Dock motion did not finish.");
            await Task.Delay(16);
        }
        _root.UpdateLayout();
    }

    private void AssertDockPresentation()
    {
        DockPresentation expected = AnchoredDock(_settings.DockEdge, _settings.IsDockCollapsed);
        bool horizontal = _settings.DockEdge is DockEdge.Top or DockEdge.Bottom;
        double expectedWidth = _settings.IsDockCollapsed ? (horizontal ? 46 : 26) : (horizontal ? 312 : 62);
        double expectedHeight = _settings.IsDockCollapsed ? (horizontal ? 26 : 46) : (horizontal ? 62 : 312);
        _root.UpdateLayout();
        if (Math.Abs(_dock.ActualWidth - expectedWidth) > 0.1 || Math.Abs(_dock.ActualHeight - expectedHeight) > 0.1
            || Math.Abs(_dockPosition.X - expected.X) > 0.1 || Math.Abs(_dockPosition.Y - expected.Y) > 0.1
            || _dockStack.Opacity != expected.ExpandedOpacity || _expand.Opacity != expected.CollapsedOpacity)
            throw new InvalidOperationException("The dock did not reach its expected size, edge, or opacity.");
        if (_dockClipGeometry is null || Math.Abs(_dockClipGeometry.Size.X - (expectedWidth - 2)) > 0.1)
            throw new InvalidOperationException("The content clip does not match the dock surface.");
    }

    private async Task SaveScreenshotAsync(string name)
    {
        _root.UpdateLayout();
        await Task.Delay(200);
        RenderTargetBitmap bitmap = new();
        await bitmap.RenderAsync(_root);
        IBuffer buffer = await bitmap.GetPixelsAsync();
        using DataReader reader = DataReader.FromBuffer(buffer);
        byte[] pixels = new byte[buffer.Length];
        reader.ReadBytes(pixels);
        StorageFolder folder = await StorageFolder.GetFolderFromPathAsync(_options.CaptureDirectory!);
        StorageFile file = await folder.CreateFileAsync(name, CreationCollisionOption.ReplaceExisting);
        using IRandomAccessStream stream = await file.OpenAsync(FileAccessMode.ReadWrite);
        BitmapEncoder encoder = await BitmapEncoder.CreateAsync(BitmapEncoder.PngEncoderId, stream);
        encoder.SetPixelData(BitmapPixelFormat.Bgra8, BitmapAlphaMode.Premultiplied,
            (uint)bitmap.PixelWidth, (uint)bitmap.PixelHeight, 96, 96, pixels);
        await encoder.FlushAsync();
    }

    private async Task FinishSmokeTestAsync(bool passed, string? error, IReadOnlyList<string> captures)
    {
        string directory = _options.CaptureDirectory!;
        Directory.CreateDirectory(directory);
        await File.WriteAllTextAsync(Path.Combine(directory, "smoke-result.json"),
            JsonSerializer.Serialize(new
            {
                passed, error, captures, animationsEnabled = _uiSettings.AnimationsEnabled,
                dockMotionFrames = _renderedMotionFrames
            }, new JsonSerializerOptions { WriteIndented = true }));
        Environment.ExitCode = passed ? 0 : 1;
        Close();
    }
}

// The grip owns pointer capture for dragging. Keep Button's keyboard activation,
// but bypass its mouse-release behavior so it cannot cancel a pending drop.
internal sealed class DockHandleButton : Button
{
    protected override void OnPointerPressed(PointerRoutedEventArgs args) => args.Handled = true;
    protected override void OnPointerReleased(PointerRoutedEventArgs args) => args.Handled = true;
}
