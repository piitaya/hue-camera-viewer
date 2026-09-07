using System.Diagnostics;
using System.Runtime.InteropServices.WindowsRuntime;
using Hue.Core;
using Microsoft.UI.Dispatching;
using Windows.Devices.Enumeration;
using Windows.Graphics.Imaging;
using Windows.Media.Capture;
using Windows.Media.Capture.Frames;
using Windows.Media.MediaProperties;
using Windows.Storage.Streams;

namespace Hue.Windows.Services;

// Construct and control the service on the UI thread. FrameReady runs on a camera thread;
// its single consumer owns the bitmap and must dispose it after presentation.
public sealed class CameraService : IAsyncDisposable
{
    private readonly DispatcherQueue dispatcher = DispatcherQueue.GetForCurrentThread()
        ?? throw new InvalidOperationException("Create the camera service on the UI thread.");
    private readonly SemaphoreSlim operations = new(1, 1);
    private readonly object frameSync = new();
    private MediaCapture? capture;
    private MediaFrameReader? reader;
    private DeviceWatcher? watcher;
    private SoftwareBitmap? latestFrame;
    private bool disposed;
    private bool demo;
    private bool wantRunning;
    private int readingFrame;
    private int refreshQueued;
    private long lastFrameTicks;

    public event Action<SoftwareBitmap>? FrameReady;
    public event Action<CameraStatus>? StatusChanged;
    public event Action<IReadOnlyList<CameraChoice>>? DevicesChanged;
    public IReadOnlyList<CameraChoice> Devices { get; private set; } = Array.Empty<CameraChoice>();
    public string? SelectedCameraId { get; private set; }
    public CameraStatus Status { get; private set; } = new(CameraState.NoCamera);
    public bool HasFrame { get { lock (frameSync) return latestFrame is not null; } }

    public async Task InitializeAsync(string? savedId, bool demo = false)
    {
        RequireUIThread();
        await operations.WaitAsync();
        try
        {
            ObjectDisposedException.ThrowIf(disposed, this);
            this.demo = demo;
            wantRunning = true;
            StopWatching();
            await StopCaptureAsync();
            if (demo)
            {
                Devices = new[] { new CameraChoice("demo", "Demo", false) };
                SelectedCameraId = "demo";
                DevicesChanged?.Invoke(Devices);
                using var image = DemoImage.Create();
                PublishFrame(SoftwareBitmap.Copy(image));
                SetStatus(CameraState.Streaming);
                return;
            }

            await ReadDevicesAsync();
            var selected = CameraSelection.SelectInitial(Devices, savedId);
            SelectedCameraId = selected?.Id;
            if (selected is not null) await StartCameraAsync(selected.Id);
            else SetStatus(CameraState.NoCamera);
            StartWatching();
        }
        catch (Exception error) when (error is not ObjectDisposedException)
        {
            await StopCaptureAsync();
            ReportError(error);
        }
        finally { operations.Release(); }
    }

    public async Task SelectCameraAsync(string id)
    {
        RequireUIThread();
        await operations.WaitAsync();
        try
        {
            ObjectDisposedException.ThrowIf(disposed, this);
            if (demo) return;
            if (!Devices.Any(device => device.Id == id)) return;
            wantRunning = true;
            SelectedCameraId = id;
            await StopCaptureAsync();
            await StartCameraAsync(id);
            if (watcher is null) StartWatching();
        }
        finally { operations.Release(); }
    }

    public async Task<string> CaptureAsync(int quarterTurns, string? directory = null)
    {
        SoftwareBitmap snapshot;
        lock (frameSync)
        {
            ObjectDisposedException.ThrowIf(disposed, this);
            if (latestFrame is null) throw new InvalidOperationException("No camera image is available.");
            snapshot = SoftwareBitmap.Copy(latestFrame);
        }

        using (snapshot)
        {
            directory ??= demo
                ? Path.Combine(Path.GetTempPath(), "Hue-Demo")
                : Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory);
            if (string.IsNullOrWhiteSpace(directory))
                throw new IOException("The Desktop folder is unavailable.");

            // The same clockwise quarter turns drive the preview and these exact pixel transforms.
            var pixels = new byte[checked(snapshot.PixelWidth * snapshot.PixelHeight * 4)];
            snapshot.CopyToBuffer(pixels.AsBuffer());
            var rotatedPixels = Rotation.RotateBgra(pixels, snapshot.PixelWidth, snapshot.PixelHeight, quarterTurns);
            var (width, height) = Rotation.Dimensions(snapshot.PixelWidth, snapshot.PixelHeight, quarterTurns);
            using var rotated = new SoftwareBitmap(BitmapPixelFormat.Bgra8, width, height, BitmapAlphaMode.Premultiplied);
            rotated.CopyFromBuffer(rotatedPixels.AsBuffer());
            using var encoded = new InMemoryRandomAccessStream();
            var encoder = await BitmapEncoder.CreateAsync(BitmapEncoder.PngEncoderId, encoded);
            encoder.SetSoftwareBitmap(rotated);
            encoder.IsThumbnailGenerated = false;
            await encoder.FlushAsync();
            encoded.Seek(0);
            using var input = encoded.GetInputStreamAt(0);
            using var data = new DataReader(input);
            var length = checked((uint)encoded.Size);
            await data.LoadAsync(length);
            var png = new byte[length];
            data.ReadBytes(png);
            return await CaptureFile.WriteAsync(directory, stream => stream.WriteAsync(png).AsTask());
        }
    }

    public async Task StopAsync()
    {
        RequireUIThread();
        await operations.WaitAsync();
        try
        {
            wantRunning = false;
            StopWatching();
            await StopCaptureAsync();
            SetStatus(CameraState.NoCamera);
        }
        finally { operations.Release(); }
    }

    public async ValueTask DisposeAsync()
    {
        RequireUIThread();
        await operations.WaitAsync();
        try
        {
            if (disposed) return;
            disposed = true;
            wantRunning = false;
            StopWatching();
            await StopCaptureAsync();
            FrameReady = null;
            StatusChanged = null;
            DevicesChanged = null;
        }
        finally { operations.Release(); }
    }

    private async Task StartCameraAsync(string id)
    {
        SetStatus(CameraState.Starting);
        try
        {
            capture = new MediaCapture();
            capture.Failed += CaptureFailed;
            await capture.InitializeAsync(new MediaCaptureInitializationSettings
            {
                VideoDeviceId = id,
                StreamingCaptureMode = StreamingCaptureMode.Video,
                MemoryPreference = MediaCaptureMemoryPreference.Cpu,
                SharingMode = MediaCaptureSharingMode.SharedReadOnly
            });
            var source = capture.FrameSources.Values
                .Where(source => source.Info.SourceKind == MediaFrameSourceKind.Color)
                .OrderBy(source => source.Info.MediaStreamType == MediaStreamType.VideoPreview ? 0 : 1)
                .FirstOrDefault() ?? throw new InvalidOperationException("The camera has no color video stream.");

            reader = await capture.CreateFrameReaderAsync(source, MediaEncodingSubtypes.Bgra8);
            reader.AcquisitionMode = MediaFrameReaderAcquisitionMode.Realtime;
            reader.FrameArrived += FrameArrived;
            var result = await reader.StartAsync();
            if (result != MediaFrameReaderStartStatus.Success)
            {
                await StopCaptureAsync();
                SetStatus(result is MediaFrameReaderStartStatus.DeviceNotAvailable
                    or MediaFrameReaderStartStatus.ExclusiveControlNotAvailable ? CameraState.Busy : CameraState.Error,
                    result.ToString());
                return;
            }
            SetStatus(CameraState.Streaming);
        }
        catch (Exception error)
        {
            await StopCaptureAsync();
            ReportError(error);
        }
    }

    private void FrameArrived(MediaFrameReader sender, MediaFrameArrivedEventArgs args)
    {
        if (Interlocked.Exchange(ref readingFrame, 1) != 0) return;
        try
        {
            var now = Stopwatch.GetTimestamp();
            if (now - lastFrameTicks < Stopwatch.Frequency / 30) return;
            using var frame = sender.TryAcquireLatestFrame();
            using var bitmap = frame?.VideoMediaFrame?.SoftwareBitmap;
            if (bitmap is null) return;
            var converted = SoftwareBitmap.Convert(bitmap, BitmapPixelFormat.Bgra8, BitmapAlphaMode.Premultiplied);
            lock (frameSync)
            {
                if (disposed || !ReferenceEquals(sender, reader))
                {
                    converted.Dispose();
                    return;
                }
                lastFrameTicks = now;
                PublishFrame(converted);
            }
        }
        catch (Exception error)
        {
            Debug.WriteLine($"Camera frame: {error.Message}");
        }
        finally { Volatile.Write(ref readingFrame, 0); }
    }

    private void PublishFrame(SoftwareBitmap bitmap)
    {
        lock (frameSync)
        {
            latestFrame?.Dispose();
            latestFrame = bitmap;
            if (FrameReady is not { } subscriber) return;
            var preview = SoftwareBitmap.Copy(bitmap);
            try { subscriber(preview); }
            catch
            {
                preview.Dispose();
                throw;
            }
        }
    }

    private async Task StopCaptureAsync()
    {
        MediaFrameReader? previousReader;
        lock (frameSync)
        {
            previousReader = reader;
            reader = null;
            latestFrame?.Dispose();
            latestFrame = null;
            lastFrameTicks = 0;
        }
        if (previousReader is not null)
        {
            previousReader.FrameArrived -= FrameArrived;
            try { await previousReader.StopAsync(); }
            catch (Exception error) { Debug.WriteLine($"Camera stop: {error.Message}"); }
            previousReader.Dispose();
        }
        if (capture is not null)
        {
            capture.Failed -= CaptureFailed;
            capture.Dispose();
            capture = null;
        }
    }

    private async Task ReadDevicesAsync()
    {
        var devices = await DeviceInformation.FindAllAsync(DeviceClass.VideoCapture);
        Devices = devices.Select(device => new CameraChoice(device.Id, device.Name,
            device.EnclosureLocation is null || device.EnclosureLocation.Panel == Panel.Unknown))
            .OrderByDescending(device => device.IsHue)
            .ThenBy(device => device.Name, StringComparer.CurrentCultureIgnoreCase)
            .ToArray();
        DevicesChanged?.Invoke(Devices);
    }

    private void StartWatching()
    {
        watcher = DeviceInformation.CreateWatcher(DeviceClass.VideoCapture);
        watcher.Added += DeviceAdded;
        watcher.Removed += DeviceRemoved;
        watcher.Updated += DeviceUpdated;
        watcher.Start();
    }

    private void StopWatching()
    {
        if (watcher is null) return;
        watcher.Added -= DeviceAdded;
        watcher.Removed -= DeviceRemoved;
        watcher.Updated -= DeviceUpdated;
        if (watcher.Status is DeviceWatcherStatus.Started or DeviceWatcherStatus.EnumerationCompleted)
            watcher.Stop();
        watcher = null;
    }

    private void DeviceAdded(DeviceWatcher sender, DeviceInformation device) => QueueDeviceRefresh();
    private void DeviceRemoved(DeviceWatcher sender, DeviceInformationUpdate device) => QueueDeviceRefresh();
    private void DeviceUpdated(DeviceWatcher sender, DeviceInformationUpdate device) => QueueDeviceRefresh();

    private void QueueDeviceRefresh()
    {
        if (Interlocked.Exchange(ref refreshQueued, 1) != 0) return;
        if (!dispatcher.TryEnqueue(async () =>
        {
            Volatile.Write(ref refreshQueued, 0);
            await operations.WaitAsync();
            try
            {
                if (disposed || demo || !wantRunning) return;
                await ReadDevicesAsync();
                var selected = CameraSelection.SelectAfterDeviceChange(Devices, SelectedCameraId);
                if (selected is null)
                {
                    await StopCaptureAsync();
                    SetStatus(SelectedCameraId is null ? CameraState.NoCamera : CameraState.Disconnected);
                }
                else if (selected.Id != SelectedCameraId || capture is null)
                {
                    SelectedCameraId = selected.Id;
                    await StopCaptureAsync();
                    await StartCameraAsync(selected.Id);
                }
            }
            catch (Exception error) { ReportError(error); }
            finally { operations.Release(); }
        })) Volatile.Write(ref refreshQueued, 0);
    }

    private void CaptureFailed(MediaCapture sender, MediaCaptureFailedEventArgs args)
    {
        dispatcher.TryEnqueue(async () =>
        {
            await operations.WaitAsync();
            try
            {
                if (disposed || !ReferenceEquals(sender, capture)) return;
                await StopCaptureAsync();
                await ReadDevicesAsync();
                SetStatus(Devices.Any(device => device.Id == SelectedCameraId) ? CameraState.Error : CameraState.Disconnected,
                    args.Message);
            }
            catch (Exception error) { ReportError(error); }
            finally { operations.Release(); }
        });
    }

    private void ReportError(Exception error)
    {
        var state = error is UnauthorizedAccessException || error.HResult == unchecked((int)0x80070005)
            ? CameraState.AccessDenied
            : error.HResult is unchecked((int)0x80070020) or unchecked((int)0x800700AA)
                ? CameraState.Busy : CameraState.Error;
        SetStatus(state, error.Message);
    }

    private void SetStatus(CameraState state, string? detail = null)
    {
        Status = new CameraStatus(state, detail);
        StatusChanged?.Invoke(Status);
    }

    private void RequireUIThread()
    {
        if (!dispatcher.HasThreadAccess)
            throw new InvalidOperationException("Control the camera service on the UI thread.");
    }
}
