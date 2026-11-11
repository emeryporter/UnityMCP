namespace UnityMCP.Editor.Core
{
    /// <summary>
    /// Shared network utility methods used by multiple components.
    /// </summary>
    public static class NetworkUtils
    {
        /// <summary>
        /// Returns the first non-loopback IPv4 address found on an active network interface,
        /// or "0.0.0.0" if none is available.
        /// </summary>
        public static string GetLanIpAddress()
        {
            try
            {
                foreach (var ni in System.Net.NetworkInformation.NetworkInterface.GetAllNetworkInterfaces())
                {
                    if (ni.OperationalStatus != System.Net.NetworkInformation.OperationalStatus.Up)
                        continue;
                    if (ni.NetworkInterfaceType == System.Net.NetworkInformation.NetworkInterfaceType.Loopback)
                        continue;

                    foreach (var addr in ni.GetIPProperties().UnicastAddresses)
                    {
                        if (addr.Address.AddressFamily == System.Net.Sockets.AddressFamily.InterNetwork)
                            return addr.Address.ToString();
                    }
                }
            }
            catch
            {
                // Fall through to default
            }
            return "0.0.0.0";
        }
    }
}
