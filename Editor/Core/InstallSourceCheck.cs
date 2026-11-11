using System.IO;
using UnityEditor.PackageManager;
using UnityEngine;

namespace UnityMCP.Editor.Core
{
    /// <summary>
    /// Builds the message for a native plugin that failed to load.
    /// Since 3.0 the plugin ships only on the `latest` branch and version tags, not on main,
    /// so a missing file usually means an old install URL or a source checkout without plugins.
    /// </summary>
    internal static class InstallSourceCheck
    {
        internal const string LatestInstallUrl = "https://github.com/emeryporter/UnityMCP.git#latest";

        /// <summary>
        /// If the plugin file exists but won't load (unsupported platform, broken binary), reports the load
        /// error. If it is missing: local/embedded checkouts need it fetched or built; anything else is most
        /// likely an old URL pointing at main.
        /// </summary>
        internal static string MissingPluginMessage(PackageSource source, bool pluginFilePresent, string loadError)
        {
            if (pluginFilePresent)
            {
                return $"[UnityMCP] Native plugin failed to load: {loadError}";
            }

            if (source == PackageSource.Local || source == PackageSource.Embedded)
            {
                return "[UnityMCP] Native plugin missing. Run Proxy~/fetch_plugins.sh or a Proxy~ build script.";
            }

            return $"[UnityMCP] The installation URL changed in 3.0. Please update to {LatestInstallUrl}";
        }

        /// <summary>
        /// True if this editor platform's plugin exists under the package root. Returns true for platforms
        /// the package ships no plugin for, so the caller reports the real load error instead of "missing".
        /// </summary>
        internal static bool IsPluginFilePresent(string packageRoot, RuntimePlatform platform)
        {
            string relativePath = PluginRelativePath(platform);
            if (relativePath == null)
            {
                return true;
            }

            string pluginPath = Path.Combine(packageRoot, relativePath);
            // A macOS .bundle may be a folder.
            return File.Exists(pluginPath) || Directory.Exists(pluginPath);
        }

        private static string PluginRelativePath(RuntimePlatform platform)
        {
            switch (platform)
            {
                case RuntimePlatform.WindowsEditor:
                    return Path.Combine("Plugins", "Windows", "x86_64", "UnityMCPProxy.dll");
                case RuntimePlatform.OSXEditor:
                    return Path.Combine("Plugins", "macOS", "UnityMCPProxy.bundle");
                case RuntimePlatform.LinuxEditor:
                    return Path.Combine("Plugins", "Linux", "x86_64", "libUnityMCPProxy.so");
                default:
                    return null;
            }
        }
    }
}
