/// Utility class for validation functions
class ValidationUtils {
  /// Checks if a string is a valid MongoDB ObjectId (24 character hex string)
  static bool isValidObjectId(String? id) {
    if (id == null) return false;
    final RegExp objectIdRegExp = RegExp(r'^[0-9a-fA-F]{24}$');
    return objectIdRegExp.hasMatch(id);
  }
} 