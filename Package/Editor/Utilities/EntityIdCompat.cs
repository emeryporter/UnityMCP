using UnityEngine;
using UnityEditor;

namespace UnityMCP.Editor.Utilities
{
    /// <summary>
    /// Backwards-compatible wrappers for Unity's instance ID APIs.
    /// Unity 6 deprecated <c>GetInstanceID()</c> and <c>InstanceIDToObject()</c>
    /// in favor of <c>GetEntityId()</c> and <c>EntityIdToObject()</c>.
    /// This class centralizes the version switch so call sites stay clean.
    /// </summary>
    internal static class EntityIdCompat
    {
        /// <summary>
        /// Returns the stable integer ID for a Unity object.
        /// On Unity 6+, uses <c>GetEntityId()</c>; on older versions, uses <c>GetInstanceID()</c>.
        /// </summary>
        internal static int GetStableId(this Object obj)
        {
#if UNITY_6000_0_OR_NEWER
            return (int)obj.GetEntityId();
#else
            return obj.GetInstanceID();
#endif
        }

        /// <summary>
        /// Resolves a Unity object from its integer ID.
        /// On Unity 6+, uses <c>EntityIdToObject()</c>; on older versions, uses <c>InstanceIDToObject()</c>.
        /// </summary>
        internal static Object ResolveObject(int instanceId)
        {
#if UNITY_6000_0_OR_NEWER
            return EditorUtility.EntityIdToObject(instanceId);
#else
            return EditorUtility.InstanceIDToObject(instanceId);
#endif
        }
    }
}
