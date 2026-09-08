using Microsoft.UI.Xaml;

namespace Girafon.Windows;

public partial class App : Application
{
    private Window? _window;

    public App() => InitializeComponent();

    protected override void OnLaunched(LaunchActivatedEventArgs args)
    {
        _window = new MainWindow(LaunchOptions.Parse(Environment.GetCommandLineArgs()));
        _window.Activate();
    }
}
