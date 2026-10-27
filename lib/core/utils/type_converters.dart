/// Comprehensive safe type conversion and parsing utilities for Edut Mobile.
/// Prevents runtime type casting exceptions such as:
/// "type 'String' is not a subtype of type 'num?' in type cast"
class TypeConverters {
  TypeConverters._();

  /// Safely converts any dynamic value into a [double].
  /// Handles `num`, `int`, `double`, `String` (with formatting/spaces/symbols), and `null`.
  static double safeDouble(dynamic value, [double defaultValue = 0.0]) {
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    if (value is String) {
      if (value.trim().isEmpty) return defaultValue;
      // Clean up common number formats (commas to dots, strip currency symbols & spaces)
      final cleaned = value
          .replaceAll('\u00A0', '') // Non-breaking space
          .replaceAll(' ', '')
          .replaceAll(',', '.')
          .replaceAll(RegExp(r'[^0-9.-]'), '');
      return double.tryParse(cleaned) ?? defaultValue;
    }
    return defaultValue;
  }

  /// Safely converts any dynamic value into an [int].
  /// Handles `num`, `int`, `double`, `String`, and `null`.
  static int safeInt(dynamic value, [int defaultValue = 0]) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      if (value.trim().isEmpty) return defaultValue;
      final cleaned = value
          .replaceAll('\u00A0', '')
          .replaceAll(' ', '')
          .replaceAll(RegExp(r'[^0-9-]'), '');
      return int.tryParse(cleaned) ?? defaultValue;
    }
    return defaultValue;
  }

  /// Safely converts any dynamic value into a clean [String].
  static String safeString(dynamic value, [String defaultValue = '']) {
    if (value == null) return defaultValue;
    final str = value.toString().trim();
    return str.isEmpty ? defaultValue : str;
  }

  /// Safely converts any dynamic value into a [bool].
  static bool safeBool(dynamic value, [bool defaultValue = false]) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final lower = value.trim().toLowerCase();
      if (lower == 'true' || lower == '1' || lower == 'yes' || lower == 'oui') return true;
      if (lower == 'false' || lower == '0' || lower == 'no' || lower == 'non') return false;
    }
    return defaultValue;
  }

  /// Formats any dynamic monetary amount into standard West African CFA Franc (FCFA) string.
  /// Example: 265000 -> "265 000 FCFA"
  static String formatCurrency(dynamic amount, {String symbol = 'FCFA', bool includeSymbol = true}) {
    final val = safeDouble(amount);
    final isNegative = val < 0;
    final absVal = val.abs();
    
    final intPart = absVal.truncate();
    final parts = <String>[];
    String str = intPart.toString();
    
    while (str.length > 3) {
      parts.insert(0, str.substring(str.length - 3));
      str = str.substring(0, str.length - 3);
    }
    parts.insert(0, str);
    
    final formatted = (isNegative ? '-' : '') + parts.join(' ');
    return includeSymbol ? '$formatted $symbol' : formatted;
  }
}
