import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'controller.dart';
import 'schema.dart';

/// Initializes a caller-owned controller, offers recovery, then displays the form.
/// Keep this widget's controller stable, or replace the widget with a new key.
class NivorquillForm extends StatefulWidget {
  const NivorquillForm({
    super.key,
    required this.controller,
    required this.child,
    this.loadingBuilder,
    this.recoveryBuilder,
    this.errorBuilder,
  });

  /// Caller-owned controller. Dispose it when the form is no longer used.
  final NivorquillFormController controller;

  /// Form content shown once initialization and recovery are resolved.
  final Widget child;

  /// Optional replacement for the default initialization progress indicator.
  final WidgetBuilder? loadingBuilder;

  /// Optional recovery UI. Call the controller's `restore` or `discard`
  /// methods to resolve the candidate, and handle any discard failure.
  /// Rebuilt while recovery is pending, including when a discard fails.
  final Widget Function(BuildContext, NivorquillFormController)?
  recoveryBuilder;

  /// Optional initialization-error UI. The controller exposes retry through
  /// `initialize` and removal through `discard`; both futures can fail.
  final Widget Function(BuildContext, NivorquillFormController, Object)?
  errorBuilder;
  @override
  State<NivorquillForm> createState() => _NivorquillFormState();
}

class _NivorquillFormState extends State<NivorquillForm> {
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void didUpdateWidget(covariant NivorquillForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) _initialize();
  }

  void _initialize() {
    unawaited(widget.controller.initialize().catchError((Object _) {}));
  }

  Future<void> _discard() async {
    try {
      await widget.controller.discard();
    } catch (_) {
      /* Controller exposes the error. */
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final c = widget.controller;
      if (!c.isInitialized) {
        if (c.lastError != null) {
          if (widget.errorBuilder != null) {
            return widget.errorBuilder!(context, c, c.lastError!);
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Unable to read your saved draft.'),
              TextButton(onPressed: _initialize, child: const Text('Retry')),
              TextButton(
                onPressed: c.isBusy ? null : _discard,
                child: const Text('Discard saved draft'),
              ),
            ],
          );
        }
        return widget.loadingBuilder?.call(context) ??
            const Center(child: CircularProgressIndicator());
      }
      if (c.hasPendingRestore) {
        if (widget.recoveryBuilder != null) {
          return widget.recoveryBuilder!(context, c);
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Continue your saved form?'),
            FilledButton(
              onPressed: c.isBusy ? null : c.restore,
              child: const Text('Restore draft'),
            ),
            TextButton(
              onPressed: c.isBusy ? null : _discard,
              child: const Text('Discard draft'),
            ),
            if (c.lastError != null)
              const Text('Could not discard the draft. Please retry.'),
          ],
        );
      }
      return widget.child;
    },
  );
}

/// Binds any custom field widget to a registered typed value and error.
class NivorquillFieldBuilder<T> extends StatelessWidget {
  const NivorquillFieldBuilder({
    super.key,
    required this.controller,
    required this.field,
    required this.builder,
  });
  final NivorquillFormController controller;
  final NivorquillField<T> field;
  final Widget Function(
    BuildContext context,
    T value,
    String? error,
    ValueChanged<T>? onChanged,
  )
  builder;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => builder(
      context,
      controller.get(field),
      controller.errorFor(field),
      controller.canEdit ? (value) => controller.set(field, value) : null,
    ),
  );
}

/// Material text input with controller-to-widget restoration and reset support.
class NivorquillTextField extends StatefulWidget {
  const NivorquillTextField({
    super.key,
    required this.controller,
    required this.field,
    this.decoration = const InputDecoration(),
    this.obscureText = false,
    this.maxLines = 1,
    this.keyboardType,
    this.focusNode,
    this.autofillHints,
    this.inputFormatters,
    this.textInputAction,
    this.onSubmitted,
  });
  final NivorquillFormController controller;
  final NivorquillField<String> field;
  final InputDecoration decoration;
  final bool obscureText;
  final int? maxLines;
  final TextInputType? keyboardType;
  final FocusNode? focusNode;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  @override
  State<NivorquillTextField> createState() => _NivorquillTextFieldState();
}

class _NivorquillTextFieldState extends State<NivorquillTextField> {
  late final TextEditingController _text;
  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.controller.get(widget.field));
    widget.controller.addListener(_sync);
  }

  void _sync() {
    final value = widget.controller.get(widget.field);
    if (_text.text != value) {
      _text.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    }
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant NivorquillTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_sync);
      widget.controller.addListener(_sync);
    }
    _sync();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_sync);
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _text,
    enabled: widget.controller.canEdit,
    decoration: widget.decoration.copyWith(
      errorText: widget.controller.errorFor(widget.field),
    ),
    obscureText: widget.obscureText,
    maxLines: widget.maxLines,
    keyboardType: widget.keyboardType,
    focusNode: widget.focusNode,
    autofillHints: widget.autofillHints,
    inputFormatters: widget.inputFormatters,
    textInputAction: widget.textInputAction,
    onSubmitted: widget.onSubmitted,
    onChanged: (value) => widget.controller.set(widget.field, value),
  );
}

/// Material dropdown supporting nullable field values when desired.
class NivorquillDropdownField<T> extends StatelessWidget {
  const NivorquillDropdownField({
    super.key,
    required this.controller,
    required this.field,
    required this.items,
    this.decoration = const InputDecoration(),
  });
  final NivorquillFormController controller;
  final NivorquillField<T> field;
  final List<DropdownMenuItem<T>> items;
  final InputDecoration decoration;
  @override
  Widget build(BuildContext context) => NivorquillFieldBuilder<T>(
    controller: controller,
    field: field,
    builder: (context, value, error, changed) => InputDecorator(
      decoration: decoration.copyWith(errorText: error),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          items: items,
          onChanged: changed == null
              ? null
              : (value) {
                  if (value != null || null is T) {
                    changed(value as T);
                  }
                },
        ),
      ),
    ),
  );
}

/// Material checkbox with validation feedback.
class NivorquillCheckboxField extends StatelessWidget {
  const NivorquillCheckboxField({
    super.key,
    required this.controller,
    required this.field,
    required this.title,
  });
  final NivorquillFormController controller;
  final NivorquillField<bool> field;
  final Widget title;
  @override
  Widget build(BuildContext context) => NivorquillFieldBuilder<bool>(
    controller: controller,
    field: field,
    builder: (context, value, error, changed) => CheckboxListTile(
      title: title,
      value: value,
      onChanged: changed == null ? null : (value) => changed(value ?? false),
      subtitle: error == null
          ? null
          : Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
    ),
  );
}

/// Visible local-save status. Includes a retry action after storage failures.
class NivorquillSaveIndicator extends StatelessWidget {
  const NivorquillSaveIndicator({super.key, required this.controller});
  final NivorquillFormController controller;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final label = switch (controller.status) {
        DraftStatus.loading => 'Loading draft…',
        DraftStatus.ready => 'Ready',
        DraftStatus.dirty => 'Unsaved changes',
        DraftStatus.saving => 'Saving…',
        DraftStatus.saved => 'Saved locally',
        DraftStatus.error => 'Draft could not be saved or loaded',
      };
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Text(label, semanticsLabel: label)),
          if (controller.status == DraftStatus.error && controller.canEdit)
            TextButton(
              onPressed: () {
                unawaited(controller.flush().catchError((Object _) {}));
              },
              child: const Text('Retry save'),
            ),
        ],
      );
    },
  );
}
