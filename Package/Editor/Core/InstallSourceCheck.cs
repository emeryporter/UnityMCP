using UnityEditor.PackageManager;

namespace UnityMCP.Editor.Core
{
    /// <summary>
    /// Explains a missing native plugin based on how the package was installed.
    /// Since 3.0 the plugin ships only on the `latest` branch and version tags, not on main.
    /// </summary>
    internal static class InstallSourceCheck
    {
        internal const string LatestInstallUrl = "https://github.com/emeryporter/UnityMCP.git#latest";

        /// <summary>
        /// Message for a DllNotFoundException: local/embedded checkouts need the plugins fetched or built;
        /// every other install is most likely an old URL pointing at main.
        /// </summary>
        internal static string MissingPluginMessage(PackageSource source)
        {
            if (source == PackageSource.Local || source == PackageSource.Embedded)
            {
                return "[UnityMCP] Native plugin missing. Run Proxy~/fetch_plugins.sh or a Proxy~ build script.";
            }

            return $"[UnityMCP] The installation URL changed in 3.0. Please update to {LatestInstallUrl}";
        }
    }
}
