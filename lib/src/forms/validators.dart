import 'package:flutter/widgets.dart';

/// Composable [FormFieldValidator]s. Pass localized [message]s from the app's
/// localizations; English defaults are provided.
///
/// ```dart
/// validator: FoundationValidators.compose([
///   FoundationValidators.required(),
///   FoundationValidators.email(),
/// ]),
/// ```
abstract final class FoundationValidators {
  static final RegExp _email = RegExp(
    r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$",
  );

  /// Runs validators in order and returns the first error.
  static FormFieldValidator<String> compose(
    List<FormFieldValidator<String>> validators,
  ) => (value) {
    for (final validator in validators) {
      final error = validator(value);
      if (error != null) return error;
    }
    return null;
  };

  static FormFieldValidator<String> required({
    String message = 'This field is required.',
  }) =>
      (value) => value == null || value.trim().isEmpty ? message : null;

  /// Empty values pass; combine with [required] when mandatory.
  static FormFieldValidator<String> email({
    String message = 'Enter a valid email address.',
  }) => (value) {
    if (value == null || value.trim().isEmpty) return null;
    return _email.hasMatch(value.trim()) ? null : message;
  };

  static FormFieldValidator<String> minLength(int length, {String? message}) =>
      (value) => value == null || value.isEmpty || value.length >= length
      ? null
      : message ?? 'Use at least $length characters.';

  static FormFieldValidator<String> maxLength(int length, {String? message}) =>
      (value) => value == null || value.length <= length
      ? null
      : message ?? 'Use at most $length characters.';

  static FormFieldValidator<String> pattern(
    RegExp pattern, {
    required String message,
  }) => (value) {
    if (value == null || value.isEmpty) return null;
    return pattern.hasMatch(value) ? null : message;
  };

  /// Accepts empty values; otherwise requires a number within the bounds.
  static FormFieldValidator<String> number({
    num? min,
    num? max,
    String message = 'Enter a valid number.',
    String? rangeMessage,
  }) => (value) {
    if (value == null || value.trim().isEmpty) return null;
    final parsed = num.tryParse(value.trim());
    if (parsed == null) return message;
    if ((min != null && parsed < min) || (max != null && parsed > max)) {
      return rangeMessage ??
          'Enter a number${min == null ? '' : ' from $min'}'
              '${max == null ? '' : ' up to $max'}.';
    }
    return null;
  };

  /// Requires the value to equal [other]'s current value (e.g. confirm
  /// password).
  static FormFieldValidator<String> matches(
    String Function() other, {
    String message = 'Values do not match.',
  }) =>
      (value) => value == other() ? null : message;
}
