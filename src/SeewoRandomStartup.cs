// SeewoRandomStartup.cs
// 希沃白板 5 随机启动图启动器 / Seewo EasiNote 5 random splash launcher
//
// 双击运行后（全程不显示任何窗口、弹窗或提示框）：
//   1) 自动定位本机希沃白板安装目录，挑出"最新版本"（EasiNote5_x.y.z.w）的
//      Main\Resources\Startup 文件夹；
//   2) 在图片库 SeewoStartup 下随机挑一个子文件夹、再随机挑其中一张图片，
//      用这张图片覆盖该 Startup 里的 SplashScreen.png；
//   3) 确认覆盖成功（SHA256 校验一致）后，才启动 swenlauncher.exe。
//
// 图片库定位（按顺序）：
//   1) 程序目录下的 library.txt（一行绝对路径，可选，方便自定义图片库位置）；
//   2) 从程序目录逐级向上最多 4 层，找名为 SeewoStartup 且里面有图片的目录：
//      - 开箱即用包里是 <包根>\dist\..\SeewoStartup；
//      - 开发时是仓库同级的 SeewoStartup。
//
// 希沃白板定位（按顺序）：
//   1) 注册表 HKLM\SOFTWARE\WOW6432Node\Seewo\EasiNote5（64 位系统）
//      或 HKLM\SOFTWARE\Seewo\EasiNote5（32 位系统）的 path / ExePath / VersionPath；
//   2) %ProgramFiles(x86)%\Seewo\EasiNote5、%ProgramFiles%\Seewo\EasiNote5。
//   安装目录下枚举 EasiNote5_*，按版本号取最高（版本号相同才比修改时间）。
//
// 权限：目标目录在 Program Files 下，普通权限写不进去。本程序平时以普通权限运行，
//   覆盖被拒绝时再以管理员身份重新拉起一个"只负责复制"的子进程（GUI 子系统 +
//   隐藏窗口），复制结果由主进程用 SHA256 校验，校验通过才启动希沃白板，
//   因此希沃白板本身仍是普通权限运行。
//
// 构建：scripts\build.ps1（使用系统自带 .NET Framework 的 csc.exe，无需额外环境）

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Security.Cryptography;
using System.Text;
using Microsoft.Win32;

internal static class Program
{
    private const string SplashFileName = "SplashScreen.png";
    private const string LibraryFileName = "library.txt";
    private const string EasiNoteRegistryKey32 = @"SOFTWARE\WOW6432Node\Seewo\EasiNote5";
    private const string EasiNoteRegistryKey64 = @"SOFTWARE\Seewo\EasiNote5";

    private static readonly string[] ImageExtensions =
        { ".png", ".jpg", ".jpeg", ".bmp", ".gif", ".webp", ".tif", ".tiff" };

    private static readonly Random Rand = new Random(Guid.NewGuid().GetHashCode());

    private static string _sourceRoot;

    [STAThread]
    private static int Main(string[] args)
    {
        // 提权子进程模式：--copy "<源图片>" "<目标文件>"，只负责覆盖复制，无任何界面。
        if (args.Length >= 3 && string.Equals(args[0], "--copy", StringComparison.OrdinalIgnoreCase))
        {
            try
            {
                CopyImage(args[1], args[2]);
                Log("elevated copy ok -> " + args[2]);
                return 0;
            }
            catch (Exception ex)
            {
                Log("elevated copy failed: " + ex);
                return 1;
            }
        }

        bool noLaunch = args.Any(a => string.Equals(a, "--no-launch", StringComparison.OrdinalIgnoreCase));

        try
        {
            string source = PickRandomImage();
            if (source == null)
            {
                Log("no usable image under " + SourceRoot);
                return 0;
            }

            string destination = ResolveDestination();
            if (destination == null)
            {
                Log("cannot locate any EasiNote Startup folder");
                return 0;
            }

            Log("source      -> " + source);
            Log("destination -> " + destination);

            if (!ReplaceImage(source, destination))
            {
                // 没有确认复制成功：不启动希沃白板，也不显示任何窗口。
                Log("copy NOT confirmed, skip launching");
                return 0;
            }

            Log("copy confirmed -> " + destination);
        }
        catch (Exception ex)
        {
            Log("unexpected: " + ex);
            return 0;
        }

        if (!noLaunch)
        {
            LaunchSeewo();
        }
        return 0;
    }

    /// <summary>图片库目录（首次访问时解析并缓存）。</summary>
    private static string SourceRoot
    {
        get
        {
            if (_sourceRoot == null)
            {
                _sourceRoot = ResolveSourceRoot();
                Log("source root -> " + _sourceRoot);
            }
            return _sourceRoot;
        }
    }

    private static string ExeDirectory
    {
        get { return Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location); }
    }

    /// <summary>定位图片库 SeewoStartup：先看 library.txt，再从程序目录逐级向上找。</summary>
    private static string ResolveSourceRoot()
    {
        string exeDirectory = ExeDirectory;

        if (!string.IsNullOrEmpty(exeDirectory))
        {
            string overrideFile = Path.Combine(exeDirectory, LibraryFileName);
            if (File.Exists(overrideFile))
            {
                string configured = File.ReadAllText(overrideFile, Encoding.UTF8).Trim();
                if (configured.Length > 0 && Directory.Exists(configured) && HasAnyImage(configured))
                {
                    Log("source root (library.txt) -> " + configured);
                    return configured;
                }
            }
        }

        string directory = exeDirectory;
        for (int level = 0; level < 4 && !string.IsNullOrEmpty(directory); level++)
        {
            string candidate = Path.Combine(directory, "SeewoStartup");
            if (Directory.Exists(candidate) && HasAnyImage(candidate))
            {
                return candidate;
            }
            DirectoryInfo parent = Directory.GetParent(directory);
            if (parent == null)
            {
                break;
            }
            directory = parent.FullName;
        }

        return Path.Combine(exeDirectory ?? ".", "SeewoStartup");
    }

    private static bool HasAnyImage(string root)
    {
        try
        {
            foreach (string directory in Directory.GetDirectories(root))
            {
                foreach (string file in Directory.GetFiles(directory, "*.*", SearchOption.AllDirectories))
                {
                    if (IsImageFile(file))
                    {
                        return true;
                    }
                }
            }
        }
        catch
        {
        }
        return false;
    }

    /// <summary>随机挑一个子文件夹、再随机挑其中一张图片。</summary>
    private static string PickRandomImage()
    {
        string root = SourceRoot;
        if (!Directory.Exists(root))
        {
            return null;
        }

        string selfDirectory = ExeDirectory;
        List<string> pool = new List<string>();

        foreach (string directory in Directory.GetDirectories(root))
        {
            // 跳过程序自己所在的文件夹，避免以后误放图片。
            if (!string.IsNullOrEmpty(selfDirectory) && SamePath(directory, selfDirectory))
            {
                continue;
            }

            string[] files;
            try
            {
                files = Directory.GetFiles(directory, "*.*", SearchOption.AllDirectories);
            }
            catch
            {
                continue;
            }

            string[] images = files.Where(IsImageFile).ToArray();
            if (images.Length == 0)
            {
                continue;
            }

            // 每个子文件夹先随机取一张，保证"先随机文件夹、再随机图片"。
            pool.Add(images[Rand.Next(images.Length)]);
        }

        if (pool.Count == 0)
        {
            return null;
        }
        return pool[Rand.Next(pool.Count)];
    }

    /// <summary>本机希沃白板安装根目录。</summary>
    private static string FindEasiNoteRoot()
    {
        string fromRegistry = ReadRegistryString(EasiNoteRegistryKey32, "path");
        if (string.IsNullOrEmpty(fromRegistry))
        {
            fromRegistry = ReadRegistryString(EasiNoteRegistryKey64, "path");
        }
        if (!string.IsNullOrEmpty(fromRegistry) && Directory.Exists(fromRegistry))
        {
            return fromRegistry;
        }

        string[] baseDirectories = new string[]
        {
            Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86),
            Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),
            @"C:\Program Files (x86)",
            @"C:\Program Files"
        };
        foreach (string baseDirectory in baseDirectories)
        {
            if (string.IsNullOrEmpty(baseDirectory))
            {
                continue;
            }
            string candidate = Path.Combine(Path.Combine(baseDirectory, "Seewo"), "EasiNote5");
            if (Directory.Exists(candidate))
            {
                return candidate;
            }
        }
        return @"C:\Program Files (x86)\Seewo\EasiNote5";
    }

    /// <summary>
    /// 找出本机"最新版本"（EasiNote5_x.y.z.w）的 Main\Resources\Startup 文件夹；
    /// 版本号解析失败时按目录修改时间比较。找不到时返回 null。
    /// </summary>
    private static string FindStartupDirectory()
    {
        string root = FindEasiNoteRoot();
        Log("easiNote root -> " + root);

        List<VersionFolder> folders = new List<VersionFolder>();
        try
        {
            foreach (string directory in Directory.GetDirectories(root))
            {
                string startup = Path.Combine(directory, "Main", "Resources", "Startup");
                if (!Directory.Exists(startup))
                {
                    continue;
                }
                folders.Add(new VersionFolder(
                    startup,
                    ParseVersion(Path.GetFileName(directory)),
                    Directory.GetLastWriteTimeUtc(directory)));
            }
        }
        catch
        {
        }

        if (folders.Count > 0)
        {
            folders.Sort(CompareVersionFolder);
            Log("startup folder -> " + folders[0].Directory);
            return folders[0].Directory;
        }

        // 兜底 1：注册表记录的最新版本目录。
        string versionPath = ReadRegistryString(EasiNoteRegistryKey32, "VersionPath");
        if (string.IsNullOrEmpty(versionPath))
        {
            versionPath = ReadRegistryString(EasiNoteRegistryKey64, "VersionPath");
        }
        if (!string.IsNullOrEmpty(versionPath))
        {
            string startup = Path.Combine(versionPath, "Main", "Resources", "Startup");
            if (Directory.Exists(startup))
            {
                Log("startup folder (registry VersionPath) -> " + startup);
                return startup;
            }
        }

        // 兜底 2：安装根目录本身就是版本目录。
        string direct = Path.Combine(root, "Main", "Resources", "Startup");
        if (Directory.Exists(direct))
        {
            return direct;
        }
        return null;
    }

    /// <summary>要覆盖的目标文件；定位不到返回 null。</summary>
    private static string ResolveDestination()
    {
        string directory = FindStartupDirectory();
        if (directory == null)
        {
            return null;
        }

        string preferred = Path.Combine(directory, SplashFileName);
        if (Directory.Exists(directory) && !File.Exists(preferred))
        {
            string[] images = Directory.GetFiles(directory).Where(IsImageFile).ToArray();
            if (images.Length == 1)
            {
                return images[0];
            }
        }
        return preferred;
    }

    /// <summary>希沃白板启动器（注册表 ExePath 优先）。</summary>
    private static string FindLauncherExe()
    {
        string fromRegistry = ReadRegistryString(EasiNoteRegistryKey32, "ExePath");
        if (string.IsNullOrEmpty(fromRegistry))
        {
            fromRegistry = ReadRegistryString(EasiNoteRegistryKey64, "ExePath");
        }
        if (!string.IsNullOrEmpty(fromRegistry) && File.Exists(fromRegistry))
        {
            return fromRegistry;
        }

        string root = FindEasiNoteRoot();
        string candidate = Path.Combine(Path.Combine(root, "swenlauncher"), "swenlauncher.exe");
        if (File.Exists(candidate))
        {
            return candidate;
        }

        try
        {
            return Directory.GetFiles(root, "swenlauncher.exe", SearchOption.AllDirectories).FirstOrDefault();
        }
        catch
        {
            return null;
        }
    }

    private static string ReadRegistryString(string subKey, string name)
    {
        try
        {
            using (RegistryKey key = Registry.LocalMachine.OpenSubKey(subKey))
            {
                if (key == null)
                {
                    return null;
                }
                object value = key.GetValue(name);
                return value == null ? null : value.ToString();
            }
        }
        catch
        {
            return null;
        }
    }

    /// <summary>从 EasiNote5_5.2.4.8772 这样的目录名里解析版本号。</summary>
    private static Version ParseVersion(string folderName)
    {
        const string prefix = "EasiNote5_";
        string text = folderName.StartsWith(prefix, StringComparison.OrdinalIgnoreCase)
            ? folderName.Substring(prefix.Length)
            : folderName;

        int end = 0;
        while (end < text.Length && (char.IsDigit(text[end]) || text[end] == '.'))
        {
            end++;
        }
        text = text.Substring(0, end).TrimEnd('.');

        Version version;
        return Version.TryParse(text, out version) ? version : null;
    }

    private static int CompareVersionFolder(VersionFolder a, VersionFolder b)
    {
        if ((a.Version != null) != (b.Version != null))
        {
            return a.Version != null ? -1 : 1;
        }
        if (a.Version != null)
        {
            int result = b.Version.CompareTo(a.Version);
            if (result != 0)
            {
                return result;
            }
        }
        return b.Time.CompareTo(a.Time);
    }

    private sealed class VersionFolder
    {
        public readonly string Directory;
        public readonly Version Version;
        public readonly DateTime Time;

        public VersionFolder(string directory, Version version, DateTime time)
        {
            Directory = directory;
            Version = version;
            Time = time;
        }
    }

    /// <summary>覆盖启动图并校验；返回是否确认复制成功。</summary>
    private static bool ReplaceImage(string source, string destination)
    {
        try
        {
            CopyImage(source, destination);
        }
        catch (Exception ex)
        {
            Log("direct copy failed: " + ex.Message);
        }

        if (FilesAreEqual(source, destination))
        {
            return true;
        }

        // 目标在 Program Files 下，普通权限写不进去：用管理员子进程再复制一次。
        Log("retrying copy with administrator rights");
        ElevatedCopy(source, destination);
        return FilesAreEqual(source, destination);
    }

    private static void CopyImage(string source, string destination)
    {
        string directory = Path.GetDirectoryName(destination);
        if (!string.IsNullOrEmpty(directory) && !Directory.Exists(directory))
        {
            Directory.CreateDirectory(directory);
        }

        if (File.Exists(destination))
        {
            FileAttributes attributes = File.GetAttributes(destination);
            if ((attributes & FileAttributes.ReadOnly) == FileAttributes.ReadOnly)
            {
                File.SetAttributes(destination, attributes & ~FileAttributes.ReadOnly);
            }
        }

        File.Copy(source, destination, true);

        FileAttributes copied = File.GetAttributes(destination);
        if ((copied & FileAttributes.ReadOnly) == FileAttributes.ReadOnly)
        {
            File.SetAttributes(destination, copied & ~FileAttributes.ReadOnly);
        }
    }

    /// <summary>
    /// 把自己以管理员身份重新拉起，只做一次复制（GUI 子系统 + 隐藏窗口）。
    /// 是否成功由主进程用 SHA256 校验目标文件决定，不依赖子进程返回值。
    /// </summary>
    private static void ElevatedCopy(string source, string destination)
    {
        try
        {
            ProcessStartInfo info = new ProcessStartInfo();
            info.FileName = Assembly.GetExecutingAssembly().Location;
            info.Arguments = "--copy " + Quote(source) + " " + Quote(destination);
            info.UseShellExecute = true;
            info.Verb = "runas";
            info.WindowStyle = ProcessWindowStyle.Hidden;

            Process process = Process.Start(info);
            if (process != null)
            {
                try { process.WaitForExit(60000); }
                catch { }
            }
        }
        catch (Exception ex)
        {
            Log("elevation failed: " + ex.Message);
        }

        DateTime deadline = DateTime.UtcNow.AddSeconds(15);
        while (DateTime.UtcNow < deadline)
        {
            if (FilesAreEqual(source, destination))
            {
                return;
            }
            System.Threading.Thread.Sleep(150);
        }
    }

    private static void LaunchSeewo()
    {
        string executable = FindLauncherExe();
        if (string.IsNullOrEmpty(executable) || !File.Exists(executable))
        {
            Log("swenlauncher not found under " + FindEasiNoteRoot());
            return;
        }

        try
        {
            ProcessStartInfo info = new ProcessStartInfo();
            info.FileName = executable;
            info.WorkingDirectory = FindEasiNoteRoot();
            info.UseShellExecute = true;
            Process.Start(info);
            Log("launched -> " + executable);
        }
        catch (Exception ex)
        {
            Log("launch failed: " + ex.Message);
        }
    }

    private static bool IsImageFile(string path)
    {
        string extension = Path.GetExtension(path);
        return ImageExtensions.Any(e => string.Equals(e, extension, StringComparison.OrdinalIgnoreCase));
    }

    private static bool SamePath(string a, string b)
    {
        try
        {
            return string.Equals(
                Path.GetFullPath(a).TrimEnd(Path.DirectorySeparatorChar),
                Path.GetFullPath(b).TrimEnd(Path.DirectorySeparatorChar),
                StringComparison.OrdinalIgnoreCase);
        }
        catch
        {
            return false;
        }
    }

    private static bool FilesAreEqual(string a, string b)
    {
        try
        {
            FileInfo infoA = new FileInfo(a);
            FileInfo infoB = new FileInfo(b);
            if (!infoA.Exists || !infoB.Exists || infoA.Length != infoB.Length)
            {
                return false;
            }

            using (SHA256 sha = SHA256.Create())
            {
                byte[] hashA;
                byte[] hashB;
                using (FileStream streamA = File.OpenRead(a))
                {
                    hashA = sha.ComputeHash(streamA);
                }
                using (FileStream streamB = File.OpenRead(b))
                {
                    hashB = sha.ComputeHash(streamB);
                }
                return hashA.SequenceEqual(hashB);
            }
        }
        catch
        {
            return false;
        }
    }

    private static string Quote(string value)
    {
        return "\"" + value.Replace("\"", "\\\"") + "\"";
    }

    private static void Log(string message)
    {
        try
        {
            string directory = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "SeewoRandomStartup");
            Directory.CreateDirectory(directory);

            string file = Path.Combine(directory, "launcher.log");
            FileInfo info = new FileInfo(file);
            if (info.Exists && info.Length > 1024 * 1024)
            {
                File.Delete(file);
            }

            File.AppendAllText(
                file,
                DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") + "  " + message + Environment.NewLine,
                new UTF8Encoding(true));
        }
        catch
        {
        }
    }
}
