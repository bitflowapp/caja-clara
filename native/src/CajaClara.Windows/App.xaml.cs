using CajaClara.Core;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml;
using System.Runtime.InteropServices;

namespace CajaClara.Windows;

public partial class App : Application
{
    private Mutex? instance;
    private MainWindow? window;
    private ServiceProvider? services;
    public static string DataDirectory { get; } = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "LUNA", "CajaClaraNative", Environment.GetCommandLineArgs().Contains("--demo") ? "Demo" : "Business");
    public App()
    {
        SafeLog("APP_CONSTRUCTOR");
        AppDomain.CurrentDomain.UnhandledException += (_, e) => SafeLog("APP_DOMAIN_FATAL", e.ExceptionObject as Exception);
        try { InitializeComponent(); SafeLog("XAML_RESOURCES_LOADED"); }
        catch (Exception error) { SafeLog("XAML_INITIALIZATION_FAILED", error); throw; }
        UnhandledException += (_, e) =>
        {
            SafeLog("UNHANDLED_UI", e.Exception);
            if (window is not null) { e.Handled = true; window.ShowError("Ocurrió un error inesperado. La operación no se confirmó. Revisá Diagnóstico."); }
        };
        TaskScheduler.UnobservedTaskException += (_, e) => { SafeLog("UNOBSERVED_TASK", e.Exception); e.SetObserved(); };
    }
    protected override void OnLaunched(LaunchActivatedEventArgs args)
    {
        try
        {
            SafeLog("ON_LAUNCHED");
            Directory.CreateDirectory(DataDirectory);
            instance = new Mutex(true, "Local\\LunaCajaClaraNative-" + Json.Hash(DataDirectory)[..20], out var created);
            if (!created) { MessageBoxW(0, "Caja Clara ya está abierta para este usuario.", "Caja Clara", 0); Exit(); return; }
            var collection = new ServiceCollection();
            collection.AddSingleton(new Store(Path.Combine(DataDirectory, "caja.sqlite")));
            collection.AddSingleton<AuthService>(); collection.AddSingleton<PosService>(); collection.AddSingleton<Reports>();
            collection.AddSingleton<MainViewModel>(); collection.AddSingleton<MainWindow>();
            services = collection.BuildServiceProvider(); window = services.GetRequiredService<MainWindow>();
            window.Closed += (_, _) => { services?.Dispose(); instance?.Dispose(); };
            SafeLog("WINDOW_CREATED"); window.Activate(); SafeLog("WINDOW_ACTIVATED");
        }
        catch (Exception e)
        {
            SafeLog("STARTUP_FAILED", e);
            MessageBoxW(0, "No se pudo iniciar Caja Clara. No se borraron tus datos. Revisá los registros en " + DataDirectory, "Caja Clara", 0x10);
            Exit();
        }
    }
    public static void SafeLog(string code, Exception? exception = null)
    {
        try
        {
            var directory = Path.Combine(DataDirectory, "logs"); Directory.CreateDirectory(directory);
            var path = Path.Combine(directory, DateTime.UtcNow.ToString("yyyy-MM-dd") + ".jsonl");
            File.AppendAllText(path, Json.Write(new { at = DateTimeOffset.UtcNow, code, exception = exception?.GetType().Name, hresult = exception?.HResult }) + Environment.NewLine);
        }
        catch (IOException) { }
        catch (UnauthorizedAccessException) { }
    }
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern int MessageBoxW(nint hwnd, string text, string caption, uint type);
}
