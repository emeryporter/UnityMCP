using System;
using System.IO;
using System.Net;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Security.Cryptography.X509Certificates;
using UnityEngine;

namespace UnityMCP.Editor.Core
{
    /// <summary>
    /// Generates or loads self-signed TLS certificates for the MCP proxy.
    /// Certificates are stored in the user's local application data directory.
    /// </summary>
    public static class CertificateGenerator
    {
        private const string CertFileName = "cert.pem";
        private const string KeyFileName = "key.pem";

        /// <summary>
        /// Gets the directory where certificates are stored.
        /// </summary>
        public static string GetCertDirectory()
        {
            string baseDir = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
            return Path.Combine(baseDir, "UnityMCP");
        }

        /// <summary>
        /// Loads existing certificates from disk, or generates new self-signed ones.
        /// Returns the PEM-encoded certificate and private key strings.
        /// </summary>
        /// <param name="directory">Directory to store/load certificates from.</param>
        /// <returns>Tuple of (certPem, keyPem) strings.</returns>
        public static (string certPem, string keyPem) GenerateOrLoad(string directory)
        {
            string certPath = Path.Combine(directory, CertFileName);
            string keyPath = Path.Combine(directory, KeyFileName);

            // Return existing cert if both files exist
            if (File.Exists(certPath) && File.Exists(keyPath))
            {
                string existingCert = File.ReadAllText(certPath);
                string existingKey = File.ReadAllText(keyPath);

                if (!string.IsNullOrWhiteSpace(existingCert) && !string.IsNullOrWhiteSpace(existingKey))
                {
                    if (CertificateContainsCurrentLanIp(existingCert))
                        return (existingCert, existingKey);

                    Debug.Log("[MCPProxy] LAN IP changed, regenerating TLS certificate.");
                    DeleteCertificate(directory);
                }
            }

            // Generate new self-signed certificate
            return GenerateNewCertificate(directory, certPath, keyPath);
        }

        /// <summary>
        /// Returns true if certificate files exist on disk.
        /// </summary>
        public static bool CertificateExists(string directory)
        {
            string certPath = Path.Combine(directory, CertFileName);
            string keyPath = Path.Combine(directory, KeyFileName);
            return File.Exists(certPath) && File.Exists(keyPath);
        }

        /// <summary>
        /// Gets the expiration date of the certificate if it exists.
        /// Returns null if the certificate does not exist or cannot be parsed.
        /// </summary>
        public static DateTimeOffset? GetCertificateExpiry(string directory)
        {
            string certPath = Path.Combine(directory, CertFileName);
            if (!File.Exists(certPath))
                return null;

            try
            {
                string certPem = File.ReadAllText(certPath);
                byte[] certBytes = DecodePem(certPem, "CERTIFICATE");
                if (certBytes == null)
                    return null;

                var cert = new X509Certificate2(certBytes);
                return new DateTimeOffset(cert.NotAfter);
            }
            catch
            {
                return null;
            }
        }

        /// <summary>
        /// Deletes existing certificate files to force regeneration.
        /// </summary>
        public static void DeleteCertificate(string directory)
        {
            string certPath = Path.Combine(directory, CertFileName);
            string keyPath = Path.Combine(directory, KeyFileName);

            if (File.Exists(certPath)) File.Delete(certPath);
            if (File.Exists(keyPath)) File.Delete(keyPath);
        }

        private static (string certPem, string keyPem) GenerateNewCertificate(
            string directory, string certPath, string keyPath)
        {
            try
            {
                using (var rsa = RSA.Create(2048))
                {
                    var request = new CertificateRequest(
                        "CN=UnityMCP Local Server",
                        rsa,
                        HashAlgorithmName.SHA256,
                        RSASignaturePadding.Pkcs1);

                    // Add Subject Alternative Names (required by modern TLS clients)
                    var sanBuilder = new SubjectAlternativeNameBuilder();
                    sanBuilder.AddIpAddress(IPAddress.Parse("127.0.0.1"));
                    sanBuilder.AddIpAddress(IPAddress.IPv6Loopback);
                    sanBuilder.AddDnsName("localhost");

                    string lanIp = NetworkUtils.GetLanIpAddress();
                    if (lanIp != "0.0.0.0" && IPAddress.TryParse(lanIp, out var lanAddr))
                        sanBuilder.AddIpAddress(lanAddr);

                    request.CertificateExtensions.Add(sanBuilder.Build());

                    var cert = request.CreateSelfSigned(
                        DateTimeOffset.UtcNow,
                        DateTimeOffset.UtcNow.AddYears(5));

                    string certPem = ExportCertificatePem(cert);
                    string keyPem = ExportRSAPrivateKeyPem(rsa);

                    // Save to disk
                    Directory.CreateDirectory(directory);
                    File.WriteAllText(certPath, certPem);
                    File.WriteAllText(keyPath, keyPem);
                    SetRestrictivePermissions(keyPath);

                    Debug.Log("[MCPProxy] Generated new self-signed TLS certificate (expires " +
                              cert.NotAfter.ToString("yyyy-MM-dd") + ")");

                    return (certPem, keyPem);
                }
            }
            catch (Exception ex)
            {
                Debug.LogWarning(
                    $"[MCPProxy] Failed to generate self-signed certificate: {ex.Message}\n" +
                    "To use remote access with TLS, place your own cert.pem and key.pem in:\n" +
                    $"  {directory}");
                return (string.Empty, string.Empty);
            }
        }

        /// <summary>
        /// Checks whether the current LAN IP is present in the certificate's SANs.
        /// Returns true if no LAN IP is detected (nothing to match) or if IP is present.
        /// Returns false if the LAN IP is missing (triggers regeneration).
        /// </summary>
        private static bool CertificateContainsCurrentLanIp(string certPem)
        {
            string lanIp = NetworkUtils.GetLanIpAddress();
            if (lanIp == "0.0.0.0")
                return true; // No LAN IP detected, nothing to match against

            try
            {
                byte[] certBytes = DecodePem(certPem, "CERTIFICATE");
                if (certBytes == null)
                    return false;

                using (var cert = new X509Certificate2(certBytes))
                {
                    foreach (var ext in cert.Extensions)
                    {
                        // OID 2.5.29.17 = Subject Alternative Name
                        if (ext.Oid?.Value == "2.5.29.17")
                        {
                            string sanText = ext.Format(true);
                            return sanText.Contains(lanIp);
                        }
                    }
                }
            }
            catch
            {
                // If we can't parse the cert, regenerate
            }
            return false;
        }

        private static string ExportCertificatePem(X509Certificate2 cert)
        {
            byte[] certBytes = cert.Export(X509ContentType.Cert);
            return "-----BEGIN CERTIFICATE-----\n" +
                   Convert.ToBase64String(certBytes, Base64FormattingOptions.InsertLineBreaks) +
                   "\n-----END CERTIFICATE-----\n";
        }

        private static string ExportRSAPrivateKeyPem(RSA rsa)
        {
            byte[] keyBytes = rsa.ExportRSAPrivateKey();
            return "-----BEGIN RSA PRIVATE KEY-----\n" +
                   Convert.ToBase64String(keyBytes, Base64FormattingOptions.InsertLineBreaks) +
                   "\n-----END RSA PRIVATE KEY-----\n";
        }

        private static byte[] DecodePem(string pem, string label)
        {
            string header = $"-----BEGIN {label}-----";
            string footer = $"-----END {label}-----";

            int start = pem.IndexOf(header, StringComparison.Ordinal);
            if (start < 0) return null;
            start += header.Length;

            int end = pem.IndexOf(footer, start, StringComparison.Ordinal);
            if (end < 0) return null;

            string base64 = pem.Substring(start, end - start).Trim();
            return Convert.FromBase64String(base64);
        }

        /// <summary>
        /// On Unix platforms, restricts file permissions to owner-only (chmod 600).
        /// Private key files should not be world-readable.
        /// </summary>
        private static void SetRestrictivePermissions(string filePath)
        {
#if UNITY_EDITOR_OSX || UNITY_EDITOR_LINUX
            try
            {
                // P/Invoke to libc chmod
                chmod(filePath, 0x180); // 0600 octal = 0x180
            }
            catch (Exception ex)
            {
                Debug.LogWarning($"[MCPProxy] Failed to set file permissions on {filePath}: {ex.Message}");
            }
#endif
        }

#if UNITY_EDITOR_OSX || UNITY_EDITOR_LINUX
        [DllImport("libc", SetLastError = true)]
        private static extern int chmod(string path, int mode);
#endif
    }
}
