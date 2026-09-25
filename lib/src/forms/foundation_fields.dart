import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../localization/foundation_strings.dart';

final class FoundationTextField extends StatelessWidget {
  const FoundationTextField({
    required this.label,
    this.controller,
    this.helperText,
    this.errorText,
    this.hintText,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.enabled = true,
    this.obscureText = false,
    this.maxLines = 1,
    this.minLines,
    this.prefixIcon,
    this.suffixIcon,
    this.inputFormatters,
    this.focusNode,
    super.key,
  });

  final String label;
  final TextEditingController? controller;
  final String? helperText;
  final String? errorText;
  final String? hintText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final bool enabled;
  final bool obscureText;
  final int? maxLines;
  final int? minLines;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final List<TextInputFormatter>? inputFormatters;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) => Semantics(
    textField: true,
    label: label,
    child: TextFormField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      validator: validator,
      maxLines: obscureText ? 1 : maxLines,
      minLines: minLines,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        errorText: errorText,
        hintText: hintText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
      ),
    ),
  );
}

final class FoundationPasswordField extends StatefulWidget {
  const FoundationPasswordField({
    required this.label,
    this.controller,
    this.validator,
    this.autofillHints = const <String>[AutofillHints.password],
    super.key,
  });

  final String label;
  final TextEditingController? controller;
  final FormFieldValidator<String>? validator;
  final Iterable<String>? autofillHints;

  @override
  State<FoundationPasswordField> createState() =>
      _FoundationPasswordFieldState();
}

final class _FoundationPasswordFieldState
    extends State<FoundationPasswordField> {
  bool hidden = true;

  @override
  Widget build(BuildContext context) => FoundationTextField(
    label: widget.label,
    controller: widget.controller,
    obscureText: hidden,
    validator: widget.validator,
    autofillHints: widget.autofillHints,
    suffixIcon: IconButton(
      tooltip: hidden
          ? FoundationStrings.of(context).showPassword
          : FoundationStrings.of(context).hidePassword,
      onPressed: () => setState(() => hidden = !hidden),
      icon: Icon(hidden ? Icons.visibility : Icons.visibility_off),
    ),
  );
}

final class FoundationSearchField extends StatelessWidget {
  const FoundationSearchField({
    required this.label,
    this.controller,
    this.onChanged,
    this.onClear,
    super.key,
  });

  final String label;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) => FoundationTextField(
    label: label,
    controller: controller,
    keyboardType: TextInputType.text,
    textInputAction: TextInputAction.search,
    onChanged: onChanged,
    prefixIcon: const Icon(Icons.search),
    suffixIcon: onClear == null
        ? null
        : IconButton(
            tooltip: FoundationStrings.of(context).clearSearch,
            onPressed: onClear,
            icon: const Icon(Icons.close),
          ),
  );
}

final class FoundationNumberField extends StatelessWidget {
  const FoundationNumberField({
    required this.label,
    this.controller,
    this.onChanged,
    this.allowDecimal = false,
    super.key,
  });

  final String label;
  final TextEditingController? controller;
  final ValueChanged<num?>? onChanged;
  final bool allowDecimal;

  @override
  Widget build(BuildContext context) => FoundationTextField(
    label: label,
    controller: controller,
    keyboardType: TextInputType.numberWithOptions(decimal: allowDecimal),
    inputFormatters: <TextInputFormatter>[
      FilteringTextInputFormatter.allow(
        allowDecimal ? RegExp(r'^\d*\.?\d*') : RegExp(r'^\d*'),
      ),
    ],
    onChanged: (value) => onChanged?.call(num.tryParse(value)),
  );
}

final class FoundationSelect<T extends Object> extends StatelessWidget {
  const FoundationSelect({
    required this.label,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    this.value,
    this.helperText,
    super.key,
  });

  final String label;
  final List<T> items;
  final String Function(T value) itemLabel;
  final ValueChanged<T?> onChanged;
  final T? value;
  final String? helperText;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<T>(
    // Keyed by value so external value changes re-seed the field.
    key: ValueKey<T?>(value),
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(labelText: label, helperText: helperText),
    items: items
        .map(
          (item) => DropdownMenuItem<T>(
            value: item,
            child: Text(itemLabel(item), overflow: TextOverflow.ellipsis),
          ),
        )
        .toList(growable: false),
    onChanged: onChanged,
  );
}

final class FoundationCheckbox extends StatelessWidget {
  const FoundationCheckbox({
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
    super.key,
  });
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => CheckboxListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    subtitle: subtitle == null ? null : Text(subtitle!),
    value: value,
    onChanged: (next) => onChanged(next ?? false),
    controlAffinity: ListTileControlAffinity.leading,
  );
}

final class FoundationRadioGroup<T extends Object> extends StatelessWidget {
  const FoundationRadioGroup({
    required this.label,
    required this.items,
    required this.itemLabel,
    required this.value,
    required this.onChanged,
    super.key,
  });
  final String label;
  final List<T> items;
  final String Function(T value) itemLabel;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: label,
    child: RadioGroup<T>(
      groupValue: value,
      onChanged: (next) {
        if (next != null) onChanged(next);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          for (final item in items)
            RadioListTile<T>(value: item, title: Text(itemLabel(item))),
        ],
      ),
    ),
  );
}

final class FoundationSlider extends StatelessWidget {
  const FoundationSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.divisions,
    this.valueLabel,
    super.key,
  });
  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String? valueLabel;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
    slider: true,
    label: label,
    value: valueLabel ?? value.toStringAsFixed(1),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        Slider(
          value: value.clamp(min, max).toDouble(),
          min: min,
          max: max,
          divisions: divisions,
          label: valueLabel,
          onChanged: onChanged,
        ),
      ],
    ),
  );
}

Future<bool?> showFoundationConfirmation(
  BuildContext context, {
  required String title,
  required String message,
  String? cancelLabel,
  String? confirmLabel,
  bool destructive = false,
}) => showDialog<bool>(
  context: context,
  builder: (context) => AlertDialog(
    title: Text(title),
    content: Text(message),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(false),
        child: Text(cancelLabel ?? FoundationStrings.of(context).cancel),
      ),
      FilledButton(
        style: destructive
            ? FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              )
            : null,
        onPressed: () => Navigator.of(context).pop(true),
        child: Text(confirmLabel ?? FoundationStrings.of(context).confirm),
      ),
    ],
  ),
);

final class FoundationSegmented<T extends Object> extends StatelessWidget {
  const FoundationSegmented({
    required this.label,
    required this.options,
    required this.optionLabel,
    required this.selected,
    required this.onChanged,
    this.multiSelectionEnabled = false,
    super.key,
  });

  final String label;
  final List<T> options;
  final String Function(T value) optionLabel;
  final Set<T> selected;
  final ValueChanged<Set<T>> onChanged;
  final bool multiSelectionEnabled;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: label,
    child: SegmentedButton<T>(
      segments: options
          .map(
            (option) => ButtonSegment<T>(
              value: option,
              label: Text(optionLabel(option)),
            ),
          )
          .toList(growable: false),
      selected: selected,
      multiSelectionEnabled: multiSelectionEnabled,
      emptySelectionAllowed: multiSelectionEnabled,
      onSelectionChanged: onChanged,
    ),
  );
}

final class FoundationChoiceChips<T extends Object> extends StatelessWidget {
  const FoundationChoiceChips({
    required this.label,
    required this.options,
    required this.optionLabel,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final String label;
  final List<T> options;
  final String Function(T value) optionLabel;
  final Set<T> selected;
  final ValueChanged<Set<T>> onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: label,
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options
          .map((option) {
            final isSelected = selected.contains(option);
            return FilterChip(
              label: Text(optionLabel(option)),
              selected: isSelected,
              onSelected: (next) {
                final updated = <T>{...selected};
                next ? updated.add(option) : updated.remove(option);
                onChanged(updated);
              },
            );
          })
          .toList(growable: false),
    ),
  );
}

final class FoundationDateTimeField extends StatelessWidget {
  const FoundationDateTimeField({
    required this.label,
    required this.displayValue,
    required this.onTap,
    this.helperText,
    this.icon = Icons.event_outlined,
    super.key,
  });

  final String label;
  final String displayValue;
  final VoidCallback onTap;
  final String? helperText;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    value: displayValue,
    child: InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          helperText: helperText,
          suffixIcon: Icon(icon),
        ),
        child: Text(displayValue),
      ),
    ),
  );
}
