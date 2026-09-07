using System.Text.Json;
using Hue.Core;
using Hue.Windows.Services;
using Microsoft.UI;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Automation;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Input;
using Microsoft.UI.Xaml.Markup;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Media.Animation;
using Microsoft.UI.Xaml.Media.Imaging;
using Microsoft.UI.Xaml.Shapes;
using Windows.Foundation;
using Windows.Graphics.Imaging;
using Windows.Storage;
using Windows.Storage.Streams;
using Windows.System;
using Path = System.IO.Path;

namespace Hue.Windows;

internal sealed class MainWindow : Window
{
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
        Padding = new Thickness(8), CornerRadius = new CornerRadius(30), BorderThickness = new Thickness(1)
    };
    private readonly Border _snapPreview = new()
    {
        Background = new SolidColorBrush(ColorHelper.FromArgb(45, 134, 216, 181)),
        BorderBrush = new SolidColorBrush(ColorHelper.FromArgb(220, 134, 216, 181)),
        BorderThickness = new Thickness(2), CornerRadius = new CornerRadius(30),
        IsHitTestVisible = false, Visibility = Visibility.Collapsed
    };
    private readonly StackPanel _dockStack = new() { Spacing = 6 };
    private readonly StackPanel _controls = new() { Spacing = 6 };
    private readonly TranslateTransform _dockPosition = new();
    private readonly List<Shape> _themeShapes = new();
    private readonly Button _grip;
    private readonly Button _cameraButton;
    private readonly Button _rotateLeft;
    private readonly Button _rotateRight;
    private readonly Button _capture;
    private readonly Button _collapse;
    private readonly RotateTransform _chevronRotation = new() { CenterX = 12, CenterY = 12 };
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
    private Storyboard? _dockAnimation;
    private CancellationTokenSource? _toastLifetime;

    public MainWindow(LaunchOptions options)
    {
        _options = options;
        _settings = options.Demo ? new AppSettings() : _settingsStore.Load();
        Title = "Hue";
        AppWindow.Resize(new global::Windows.Graphics.SizeInt32(1120, 780));
        string icon = Path.Combine(AppContext.BaseDirectory, "Assets", "Hue.ico");
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

        _grip = MakeButton("Move controls", MakeGrip(), new DockHandleButton());
        _grip.Click += (_, _) => ShowDockMenu();
        _grip.AddHandler(UIElement.PointerPressedEvent, new PointerEventHandler(GripPressed), true);
        _grip.AddHandler(UIElement.PointerMovedEvent, new PointerEventHandler(GripMoved), true);
        _grip.AddHandler(UIElement.PointerReleasedEvent, new PointerEventHandler(GripReleased), true);
        _grip.PointerCanceled += (_, _) => FinishDrag(false);
        _grip.PointerCaptureLost += (_, _) => FinishDrag(false);

        _cameraButton = MakeButton("Choose camera", MakeGlyph("M 4 5 H 14 Q 16 5 16 7 V 17 Q 16 19 14 19 H 4 Q 2 19 2 17 V 7 Q 2 5 4 5 Z M 16 9 L 22 6 V 18 L 16 15"));
        _cameraButton.Click += (_, _) => ShowCameraMenu();
        _rotateLeft = MakeButton("Rotate left", MakeGlyph("M 4 10 A 8 8 0 1 1 5 18 M 4 4 V 10 H 10"));
        _rotateLeft.Click += (_, _) => Rotate(-1);
        _rotateRight = MakeButton("Rotate right", MakeGlyph("M 20 10 A 8 8 0 1 0 19 18 M 20 4 V 10 H 14"));
        _rotateRight.Click += (_, _) => Rotate(1);
        _capture = MakeButton("Capture image", MakeGlyph("M 4 6 H 7 L 9 3 H 15 L 17 6 H 20 Q 22 6 22 8 V 19 Q 22 21 20 21 H 4 Q 2 21 2 19 V 8 Q 2 6 4 6 Z M 16 13 A 4 4 0 1 1 8 13 A 4 4 0 1 1 16 13", true));
        _capture.Background = new SolidColorBrush(ColorHelper.FromArgb(255, 134, 216, 181));
        _capture.Resources["ButtonBackgroundPointerOver"] = new SolidColorBrush(ColorHelper.FromArgb(255, 160, 231, 200));
        _capture.Resources["ButtonBackgroundPressed"] = new SolidColorBrush(ColorHelper.FromArgb(255, 107, 193, 157));
        _capture.Click += async (_, _) => await CaptureAsync();
        Canvas chevron = MakeGlyph("M 8 5 L 15 12 L 8 19");
        chevron.RenderTransform = _chevronRotation;
        _collapse = MakeButton("Hide controls", chevron);
        _collapse.Click += (_, _) =>
        {
            _settings = _settings with { IsDockCollapsed = !_settings.IsDockCollapsed };
            LayoutDock(true);
            SaveSettings();
        };

        foreach (Button control in new[] { _cameraButton, _rotateLeft, _rotateRight, _capture }) _controls.Children.Add(control);
        _dockStack.Children.Add(_grip);
        _dockStack.Children.Add(_controls);
        _dockStack.Children.Add(_collapse);
        _dock.Child = _dockStack;
        _dock.RenderTransform = _dockPosition;
        _overlay.Children.Add(_snapPreview);
        _overlay.Children.Add(_dock);

        _root.SizeChanged += (_, _) => { LayoutPreview(); if (!_dragging) LayoutDock(false); };
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
            item.Click += (_, _) => { _settings = _settings with { DockEdge = edge }; LayoutDock(true); SaveSettings(); };
            menu.Items.Add(item);
        }
        menu.ShowAt(_grip);
    }

    private (double Width, double Height) DockSize(DockEdge edge)
    {
        double length = _settings.IsDockCollapsed ? 112 : 312;
        return edge is DockEdge.Top or DockEdge.Bottom ? (length, 62) : (62, length);
    }

    private void LayoutDock(bool animate)
    {
        if (_root.ActualWidth <= 0 || _root.ActualHeight <= 0) return;
        bool horizontal = _settings.DockEdge is DockEdge.Top or DockEdge.Bottom;
        _dockStack.Orientation = _controls.Orientation = horizontal ? Orientation.Horizontal : Orientation.Vertical;
        _controls.Visibility = _settings.IsDockCollapsed ? Visibility.Collapsed : Visibility.Visible;
        string label = Strings.Get(_settings.IsDockCollapsed ? "Show controls" : "Hide controls");
        ToolTipService.SetToolTip(_collapse, label);
        AutomationProperties.SetName(_collapse, label);
        _chevronRotation.Angle = (_settings.DockEdge switch
        {
            DockEdge.Right => 0, DockEdge.Bottom => 90, DockEdge.Left => 180, _ => 270
        }) + (_settings.IsDockCollapsed ? 180 : 0);
        var size = DockSize(_settings.DockEdge);
        _dock.Width = size.Width;
        _dock.Height = size.Height;
        DockPoint position = DockGeometry.Position(_settings.DockEdge, _root.ActualWidth, _root.ActualHeight, size.Width, size.Height);
        MoveDock(position.X, position.Y, animate);
    }

    private void MoveDock(double x, double y, bool animate)
    {
        double previousX = _dockPosition.X;
        double previousY = _dockPosition.Y;
        _dockAnimation?.Stop();
        _dockPosition.X = x;
        _dockPosition.Y = y;
        if (!animate) return;
        Storyboard storyboard = new();
        AddAnimation(storyboard, "X", previousX, x);
        AddAnimation(storyboard, "Y", previousY, y);
        _dockAnimation = storyboard;
        storyboard.Begin();
    }

    private void AddAnimation(Storyboard storyboard, string property, double from, double to)
    {
        DoubleAnimation animation = new()
        {
            From = from, To = to, Duration = new Duration(TimeSpan.FromMilliseconds(220)),
            EasingFunction = new CubicEase { EasingMode = EasingMode.EaseOut }
        };
        Storyboard.SetTarget(animation, _dockPosition);
        Storyboard.SetTargetProperty(animation, property);
        storyboard.Children.Add(animation);
    }

    private void GripPressed(object sender, PointerRoutedEventArgs args)
    {
        var point = args.GetCurrentPoint(_root);
        if (!point.Properties.IsLeftButtonPressed) return;
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
        MoveDock(current.X, current.Y, false);
        _candidateEdge = DockGeometry.NearestEdge(point.X, point.Y, _root.ActualWidth, _root.ActualHeight, _candidateEdge);
        var size = DockSize(_candidateEdge);
        DockPoint target = DockGeometry.Position(_candidateEdge, _root.ActualWidth, _root.ActualHeight, size.Width, size.Height);
        _snapPreview.Width = size.Width;
        _snapPreview.Height = size.Height;
        Canvas.SetLeft(_snapPreview, target.X);
        Canvas.SetTop(_snapPreview, target.Y);
        _snapPreview.Visibility = Visibility.Visible;
    }

    private void GripReleased(object sender, PointerRoutedEventArgs args)
    {
        if (!_dragging) return;
        bool moved = _dragMoved;
        FinishDrag(true);
        _grip.ReleasePointerCapture(args.Pointer);
        args.Handled = true;
        if (!moved) ShowDockMenu();
    }

    private void FinishDrag(bool commit)
    {
        if (!_dragging) return;
        _dragging = false;
        _snapPreview.Visibility = Visibility.Collapsed;
        if (commit && _dragMoved)
        {
            _settings = _settings with { DockEdge = _candidateEdge };
            SaveSettings();
        }
        LayoutDock(_dragMoved);
    }

    private void ApplyTheme()
    {
        bool dark = _root.ActualTheme == ElementTheme.Dark;
        var tint = dark ? ColorHelper.FromArgb(255, 35, 38, 40) : ColorHelper.FromArgb(255, 246, 247, 245);
        _dock.Background = new AcrylicBrush { TintColor = tint, TintOpacity = 0.88, FallbackColor = tint };
        _dock.BorderBrush = new SolidColorBrush(dark ? ColorHelper.FromArgb(255, 85, 90, 91) : ColorHelper.FromArgb(255, 203, 208, 207));
        Brush foreground = new SolidColorBrush(dark ? ColorHelper.FromArgb(255, 241, 244, 243) : ColorHelper.FromArgb(255, 35, 45, 43));
        foreach (Shape shape in _themeShapes)
        {
            if (shape is Ellipse) shape.Fill = foreground;
            else shape.Stroke = foreground;
        }
    }

    private Canvas MakeGlyph(string data, bool capture = false)
    {
        Canvas canvas = new() { Width = 24, Height = 24 };
        var path = (Microsoft.UI.Xaml.Shapes.Path)XamlReader.Load($"<Path xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation' Data='{data}' StrokeThickness='1.9' StrokeLineJoin='Round' StrokeStartLineCap='Round' StrokeEndLineCap='Round' />");
        if (capture) path.Stroke = new SolidColorBrush(ColorHelper.FromArgb(255, 14, 40, 31));
        else _themeShapes.Add(path);
        canvas.Children.Add(path);
        return canvas;
    }

    private Canvas MakeGrip()
    {
        Canvas canvas = new() { Width = 24, Height = 24 };
        foreach (double x in new[] { 6.5, 13.5 })
        foreach (double y in new[] { 3.5, 10.5, 17.5 })
        {
            Ellipse dot = new() { Width = 3.5, Height = 3.5 };
            Canvas.SetLeft(dot, x);
            Canvas.SetTop(dot, y);
            canvas.Children.Add(dot);
            _themeShapes.Add(dot);
        }
        return canvas;
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
            JsonSerializer.Serialize(new { passed, error, captures }, new JsonSerializerOptions { WriteIndented = true }));
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
