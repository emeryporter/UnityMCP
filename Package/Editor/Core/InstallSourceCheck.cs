using UnityEditor;
using UnityEditor.PackageManager;
using UnityEngine;
using PackageInfo = UnityEditor.PackageManager.PackageInfo;

namespace UnityMCP.Editor.Core
{
    /// <summary>
    /// Warns users who install the package from an unpinned git URL (the main branch),
    /// which stops shipping native binaries in 3.0.
    /// </summary>
    [InitializeOnLoad]
    internal static class InstallSourceCheck
    {
        internal const string LatestInstallUrl = "https://github.com/emeryporter/UnityMCP.git#latest";

        static InstallSourceCheck()
        {
            PackageInfo packageInfo = PackageInfo.FindForAssembly(typeof(InstallSourceCheck).Assembly);
            if (packageInfo != null && IsUnpinnedGitInstall(packageInfo.source, packageInfo.packageId))
            {
                Debug.LogWarning($"[UnityMCP] The installation URL is changing as part of 3.0. Please update to {LatestInstallUrl}");
            }
        }

        /// <summary>
        /// True when the package comes from git with no #branch or #tag in its URL.
        /// </summary>
        internal static bool IsUnpinnedGitInstall(PackageSource source, string packageId)
        {
            return source == PackageSource.Git && packageId != null && !packageId.Contains("#");
        }
    }
}
