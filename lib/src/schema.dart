import 'dart:convert';

/// A typed conversion between application values and JSON-compatible data.
class NivorquillCodec<T> {
  const NivorquillCodec({required this.encode, required this.decode});

  /// Converts a value to JSON-compatible data. Preserve round-trip semantics.
  final Object? Function(T value) encode;

  /// Decodes JSON data; return fresh collections for mutable value types.
  final T Function(Object? json) decode;

  static final text = NivorquillCodec<String>(
    encode: (v) => v,
    decode: (v) => v as String,
  );
  static final boolean = NivorquillCodec<bool>(
    encode: (v) => v,
    decode: (v) => v as bool,
  );
  static final integer = NivorquillCodec<int>(
    encode: (v) => v,
    decode: (v) => v as int,
  );
  static final decimal = NivorquillCodec<double>(
    encode: (v) => v,
    decode: (v) => (v as num).toDouble(),
  );
  static final dateTime = NivorquillCodec<DateTime>(
    encode: (v) => v.toUtc().toIso8601String(),
    decode: (v) => DateTime.parse(v as String),
  );

  /// Stores the calendar components of a DateTime as YYYY-MM-DD, without
  /// converting time zones. Decoding returns a local midnight DateTime.
  static final dateOnly = NivorquillCodec<DateTime>(
    encode: (v) {
      if (v.year < 1 || v.year > 9999) {
        throw FormatException('Year out of range');
      }
      return '${v.year.toString().padLeft(4, '0')}-'
          '${v.month.toString().padLeft(2, '0')}-'
          '${v.day.toString().padLeft(2, '0')}';
    },
    decode: (v) {
      final match = RegExp(
        r'^(\d{4})-(\d{2})-(\d{2})$',
      ).firstMatch(v as String);
      if (match == null) throw FormatException('Invalid calendar date', v);
      final year = int.parse(match[1]!);
      final month = int.parse(match[2]!);
      final day = int.parse(match[3]!);
      final date = DateTime(year, month, day);
      if (date.year != year || date.month != month || date.day != day) {
        throw FormatException('Invalid calendar date', v);
      }
      return date;
    },
  );

  /// Adds null support to an existing codec.
  NivorquillCodec<T?> nullable() => NivorquillCodec<T?>(
    encode: (v) => v == null ? null : encode(v),
    decode: (v) => v == null ? null : decode(v),
  );
}

/// Detached typed values supplied to validators and submission callbacks.
/// The top-level map is immutable; nested mutable values belong to the snapshot.
class NivorquillFormValues {
  NivorquillFormValues(Map<String, Object?> values)
    : _values = Map.unmodifiable(values);
  final Map<String, Object?> _values;
  T get<T>(NivorquillField<T> field) => _values[field.id] as T;
  Map<String, Object?> get asMap => _values;
}

/// Type-erased schema boundary. Applications normally construct [NivorquillField].
abstract class NivorquillFieldDefinition {
  String get id;
  bool get persist;
  Object? initial();
  Object? encodeValue(Object? value);
  Object? decodeValue(Object? value);
  String? validateValue(Object? value, NivorquillFormValues values);
}

/// A field's stable identifier, codec, default value and optional validator.
/// Persistence is opt-in. Never opt passwords, OTPs or payment secrets in.
class NivorquillField<T> implements NivorquillFieldDefinition {
  NivorquillField({
    required this.id,
    required this.initialValue,
    required this.codec,
    this.persist = false,
    this.validator,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id');
    }
    _initialJson = jsonEncode(codec.encode(initialValue));
    codec.decode(jsonDecode(_initialJson));
  }
  @override
  final String id;

  /// Original default; a JSON snapshot is captured when the field is created.
  final T initialValue;
  late final String _initialJson;
  final NivorquillCodec<T> codec;
  @override
  /// Explicitly permits this field to be saved and restored locally.
  final bool persist;

  /// Returns an error message, or null when the value is valid.
  final String? Function(T value, NivorquillFormValues values)? validator;
  @override
  Object? initial() => decodeValue(jsonDecode(_initialJson));
  @override
  Object? encodeValue(Object? value) =>
      jsonDecode(jsonEncode(codec.encode(value as T)));
  @override
  Object? decodeValue(Object? value) => codec.decode(value);
  @override
  String? validateValue(Object? value, NivorquillFormValues values) =>
      validator?.call(value as T, values);
}

/// Reusable synchronous validators. Combine with [all].
abstract final class NivorquillValidators {
  static String? Function(String, NivorquillFormValues) requiredText({
    String message = 'Required',
  }) =>
      (value, _) => value.trim().isEmpty ? message : null;
  static String? Function(String, NivorquillFormValues) minLength(
    int length, {
    String? message,
  }) {
    if (length < 0) throw ArgumentError.value(length, 'length');
    return (value, _) => value.runes.length < length
        ? message ?? 'Use at least $length characters'
        : null;
  }

  static String? Function(T, NivorquillFormValues) all<T>(
    List<String? Function(T, NivorquillFormValues)> validators,
  ) {
    final copy = List<String? Function(T, NivorquillFormValues)>.of(validators);
    return (value, values) {
      for (final validator in copy) {
        final error = validator(value, values);
        if (error != null) return error;
      }
      return null;
    };
  }

  /// Validates an optional value as present; additional rules remain app-defined.
  static String? Function(T?, NivorquillFormValues) requiredValue<T>({
    String message = 'Required',
  }) =>
      (value, _) => value == null ? message : null;

  /// Inclusive numeric bounds. Non-finite values are always rejected.
  static String? Function(num, NivorquillFormValues) range({
    required num min,
    required num max,
    String? message,
  }) {
    if (!min.isFinite || !max.isFinite || min > max) {
      throw ArgumentError('Invalid range');
    }
    return (value, _) => !value.isFinite || value < min || value > max
        ? message ?? 'Use a value between $min and $max'
        : null;
  }

  /// Matches an application-supplied regular expression.
  static String? Function(String, NivorquillFormValues) pattern(
    RegExp expression, {
    String message = 'Invalid format',
  }) =>
      (value, _) => expression.hasMatch(value) ? null : message;

  static String? accepted(bool value, NivorquillFormValues _) =>
      value ? null : 'Please accept to continue';
}
