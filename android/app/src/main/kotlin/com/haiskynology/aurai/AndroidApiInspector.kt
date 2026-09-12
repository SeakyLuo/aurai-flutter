package com.haiskynology.aurai

object AndroidApiInspector {
    fun inspect(className: String, filter: String, offset: Int): Map<String, Any?> {
        if (offset < 0) return mapOf("success" to false, "error" to "offset must be nonnegative")
        return try {
            val type = Class.forName(className, false, AndroidApiInspector::class.java.classLoader)
            val members = (type.constructors.map { it.toGenericString() } +
                type.methods.map { it.toGenericString() } +
                type.fields.map { it.toGenericString() })
                .filter { it.contains(filter, ignoreCase = true) }.distinct().sorted()
            mapOf(
                "success" to true, "className" to type.name,
                "members" to members.drop(offset).take(40), "total" to members.size,
                "nextOffset" to if (offset + 40 < members.size) offset + 40 else null,
                "note" to "Public signatures present on this device, not a permission grant. Use Packages with Java binary class names; nested classes contain a dollar sign.",
            )
        } catch (error: ReflectiveOperationException) {
            mapOf("success" to false, "error" to "${error.javaClass.simpleName}: ${error.message}")
        } catch (error: LinkageError) {
            mapOf("success" to false, "error" to "${error.javaClass.simpleName}: ${error.message}")
        }
    }
}
