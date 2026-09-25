import 'package:flutter/material.dart';
import 'package:flutter_app_foundation/foundation_preset_minimal.dart';

final class ComponentsPage extends StatefulWidget {
  const ComponentsPage({super.key});

  @override
  State<ComponentsPage> createState() => _ComponentsPageState();
}

final class _ComponentsPageState extends State<ComponentsPage> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  var _intensity = 3.0;
  var _reminders = true;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _form,
    child: ListView(
      padding: const EdgeInsets.all(FoundationSpacing.lg),
      children: <Widget>[
        Text(
          'Accessible fields',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: FoundationSpacing.md),
        FoundationTextField(
          label: 'Email',
          helperText: 'Labels and helper text are always explicit.',
          keyboardType: TextInputType.emailAddress,
          autofillHints: const <String>[AutofillHints.email],
          validator: FoundationValidators.compose(<FormFieldValidator<String>>[
            FoundationValidators.required(),
            FoundationValidators.email(),
          ]),
        ),
        const SizedBox(height: FoundationSpacing.md),
        FoundationPasswordField(
          label: 'Password',
          controller: _password,
          validator: FoundationValidators.minLength(8),
        ),
        const SizedBox(height: FoundationSpacing.md),
        FoundationSlider(
          label: 'Reminder intensity',
          value: _intensity,
          min: 1,
          max: 5,
          divisions: 4,
          valueLabel: _intensity.round().toString(),
          onChanged: (value) => setState(() => _intensity = value),
        ),
        FoundationCheckbox(
          label: 'Allow reminders',
          subtitle: 'The product decides when to request permission.',
          value: _reminders,
          onChanged: (value) => setState(() => _reminders = value),
        ),
        const SizedBox(height: FoundationSpacing.md),
        FoundationAsyncButton(
          label: 'Validate and save',
          expand: true,
          onPressed: () async {
            if (!_form.currentState!.validate()) return;
            await Future<void>.delayed(const Duration(milliseconds: 600));
            if (context.mounted) showFoundationSnackBar(context, 'Saved.');
          },
        ),
      ],
    ),
  );
}
