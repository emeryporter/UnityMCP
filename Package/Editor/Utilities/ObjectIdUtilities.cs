using System;
using System.Globalization;
using UnityEditor;

namespace UnityMCP.Editor.Utilities
{
    /// <summary>
    /// Version-safe conversion between Unity objects and the numeric IDs exposed over MCP.
    /// </summary>
    /// <remarks>
    /// Unity 6000.4 replaced int instance IDs with the 64-bit <c>EntityId</c>, and 6000.6 made the
    /// int APIs (<c>GetInstanceID</c>, <c>InstanceIDToObject</c>, int casts) obsolete-as-error.
    /// IDs are exposed as a signed <see cref="long"/>: the raw EntityId bits on 6000.4+, the legacy
    /// int on older versions. The JSON type stays a number, but on 6000.6 values use the high 32 bits
    /// (observed ~2^43), so they no longer match legacy int IDs. Observed values stay below 2^53,
    /// keeping them exact in JavaScript clients.
    /// </remarks>
    public static class ObjectIdUtilities
    {
        /// <summary>
        /// Returns the MCP ID for a Unity object, or 0 if the object is null.
        /// </summary>
        public static long GetId(UnityEngine.Object unityObject)
        {
            if (unityObject == null)
            {
                return 0;
            }
#if UNITY_6000_4_OR_NEWER
            return unchecked((long)UnityEngine.EntityId.ToULong(unityObject.GetEntityId()));
#else
            return unityObject.GetInstanceID();
#endif
        }

        /// <summary>
        /// Resolves an MCP ID to a Unity object. Returns null if no object has that ID.
        /// </summary>
        public static UnityEngine.Object FindById(long objectId)
        {
            if (objectId == 0)
            {
                return null;
            }
#if UNITY_6000_4_OR_NEWER
            return EditorUtility.EntityIdToObject(UnityEngine.EntityId.FromULong(unchecked((ulong)objectId)));
#else
            if (objectId < int.MinValue || objectId > int.MaxValue)
            {
                return null;
            }
            return EditorUtility.InstanceIDToObject((int)objectId);
#endif
        }

        /// <summary>
        /// Parses an MCP ID from a JSON value (int, long, double without fraction, or numeric string).
        /// </summary>
        public static bool TryParseId(object rawValue, out long objectId)
        {
            objectId = 0;
            switch (rawValue)
            {
                case null:
                    return false;
                case long longValue:
                    objectId = longValue;
                    return true;
                case int intValue:
                    objectId = intValue;
                    return true;
                case short shortValue:
                    objectId = shortValue;
                    return true;
                case double doubleValue:
                    if (Math.Floor(doubleValue) != doubleValue || doubleValue < long.MinValue || doubleValue > long.MaxValue)
                    {
                        return false;
                    }
                    objectId = (long)doubleValue;
                    return true;
                case string stringValue:
                    return long.TryParse(stringValue.Trim(), NumberStyles.AllowLeadingSign, CultureInfo.InvariantCulture, out objectId);
                default:
                    if (rawValue is IConvertible)
                    {
                        try
                        {
                            objectId = Convert.ToInt64(rawValue, CultureInfo.InvariantCulture);
                            return true;
                        }
                        catch (Exception)
                        {
                            return false;
                        }
                    }
                    return false;
            }
        }

        /// <summary>
        /// True when a SerializedProperty object reference points at an ID that no longer resolves
        /// (a "missing" reference shown as "Missing (Type)" in the Inspector).
        /// </summary>
        public static bool HasDanglingReference(SerializedProperty property)
        {
            if (property.propertyType != SerializedPropertyType.ObjectReference || property.objectReferenceValue != null)
            {
                return false;
            }
#if UNITY_6000_4_OR_NEWER
            return property.objectReferenceEntityIdValue != UnityEngine.EntityId.None;
#else
            return property.objectReferenceInstanceIDValue != 0;
#endif
        }
    }
}
