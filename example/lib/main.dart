import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nivorquill_form_lib/nivorquill_form_lib.dart';

void main() => runApp(
  MaterialApp(
    theme: ThemeData(
      colorSchemeSeed: const Color(0xff385b77),
      useMaterial3: true,
    ),
    home: const ListingForm(),
  ),
);

class ListingForm extends StatefulWidget {
  const ListingForm({super.key, this.store});
  final DraftStore? store;
  @override
  State<ListingForm> createState() => _ListingFormState();
}

class _ListingFormState extends State<ListingForm> with WidgetsBindingObserver {
  final title = NivorquillField(
    id: 'title',
    initialValue: '',
    codec: NivorquillCodec.text,
    persist: true,
    validator: NivorquillValidators.requiredText(),
  );
  final description = NivorquillField(
    id: 'description',
    initialValue: '',
    codec: NivorquillCodec.text,
    persist: true,
    validator: NivorquillValidators.minLength(10),
  );
  final category = NivorquillField(
    id: 'category',
    initialValue: 'Furniture',
    codec: NivorquillCodec.text,
    persist: true,
  );
  final accepted = NivorquillField(
    id: 'accepted',
    initialValue: false,
    codec: NivorquillCodec.boolean,
    validator: NivorquillValidators.accepted,
  );
  late final NivorquillFormController form;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    form = NivorquillFormController(
      key: const DraftKey(
        namespace: 'demo',
        userId: 'local-user',
        formId: 'listing',
      ),
      store: widget.store ?? PreferencesDraftStore(),
      fields: [title, description, category, accepted],
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive && form.canEdit) {
      unawaited(form.flush().catchError((Object _) {}));
    }
  }

  Future<void> _submit() async {
    try {
      final success = await form.submit((values) async {
        // Replace with your server call. This example does not send data.
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Demo submission complete. Draft cleared.'),
          ),
        );
      }
    } on DraftCleanupException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Submitted. Use Discard to retry local cleanup; do not submit again.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not submit: $error')));
      }
    }
  }

  Future<void> _discard() async {
    try {
      await form.discard();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not clear draft. Please retry.')),
        );
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    form.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Nivorquill Form Lib')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: NivorquillForm(
              controller: form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Finish it later.',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Create a listing. Close and reopen the app to try recovery. Only the three explicitly opted-in fields are stored.',
                  ),
                  const SizedBox(height: 24),
                  NivorquillTextField(
                    textInputAction: TextInputAction.next,
                    controller: form,
                    field: title,
                    decoration: const InputDecoration(
                      labelText: 'Listing title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  NivorquillTextField(
                    controller: form,
                    field: description,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  NivorquillDropdownField(
                    controller: form,
                    field: category,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    items: ['Furniture', 'Electronics', 'Other']
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                  ),
                  NivorquillCheckboxField(
                    controller: form,
                    field: accepted,
                    title: const Text('I confirm the listing is accurate'),
                  ),
                  const SizedBox(height: 12),
                  NivorquillSaveIndicator(controller: form),
                  const SizedBox(height: 16),
                  ListenableBuilder(
                    listenable: form,
                    builder: (context, _) => FilledButton(
                      onPressed: form.canEdit ? _submit : null,
                      child: Text(form.isBusy ? 'Submitting…' : 'Submit demo'),
                    ),
                  ),
                  ListenableBuilder(
                    listenable: form,
                    builder: (context, _) => TextButton(
                      onPressed: form.isBusy ? null : _discard,
                      child: const Text('Discard and start over'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
