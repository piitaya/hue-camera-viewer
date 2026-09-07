namespace Hue.Core;

public static class CaptureFile
{
    public static async Task<string> WriteAsync(string directory, Func<Stream, Task> write)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(directory);
        Directory.CreateDirectory(directory);
        var stem = $"Hue-{DateTime.Now:yyyy-MM-dd-HHmmss-fff}-{Guid.NewGuid():N}";
        var destination = Path.Combine(directory, stem + ".png");
        var temporary = Path.Combine(directory, "." + stem + ".tmp");
        try
        {
            await using (var stream = new FileStream(temporary, FileMode.CreateNew, FileAccess.Write,
                FileShare.None, 65536, FileOptions.Asynchronous))
            {
                await write(stream);
                await stream.FlushAsync();
                stream.Flush(true);
            }
            File.Move(temporary, destination, overwrite: false);
            return destination;
        }
        finally
        {
            if (File.Exists(temporary)) File.Delete(temporary);
        }
    }
}
