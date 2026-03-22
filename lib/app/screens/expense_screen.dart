import 'package:flutter/material.dart';

import '../services/commerce_store.dart';
import '../utils/formatters.dart';
import '../utils/user_facing_errors.dart';
import '../utils/text_field_selection.dart';
import '../widgets/commerce_components.dart';
import '../widgets/commerce_scope.dart';
import '../widgets/keyboard_aware_form.dart';
import '../widgets/speech_dictation.dart';

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _conceptController = TextEditingController();
  final _categoryController = TextEditingController(text: 'Insumos');
  final _amountController = TextEditingController();
  final _conceptFocusNode = FocusNode();
  final _amountFocusNode = FocusNode();
  final _categoryFocusNode = FocusNode();
  final _conceptDictation = SpeechDictationController();
  final _categoryDictation = SpeechDictationController();
  DateTime _dateTime = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _conceptDictation.initialize();
    _categoryDictation.initialize();
    selectAllTextOnFocus(_categoryFocusNode, _categoryController);
  }

  @override
  void dispose() {
    _conceptController.dispose();
    _categoryController.dispose();
    _amountController.dispose();
    _conceptFocusNode.dispose();
    _amountFocusNode.dispose();
    _categoryFocusNode.dispose();
    _conceptDictation.dispose();
    _categoryDictation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = CommerceScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar gasto')),
      body: KeyboardAwarePageBody(
        child: BpcPanel(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nuevo gasto',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  'Anota el gasto, guarda y sigue. Sin vueltas.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _conceptController,
                  focusNode: _conceptFocusNode,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Concepto',
                    suffixIcon: SpeechDictationActionButton(
                      controller: _conceptDictation,
                      textController: _conceptController,
                      tooltip: 'Dictar concepto',
                    ),
                  ),
                  onFieldSubmitted: (_) => _amountFocusNode.requestFocus(),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Escribi un concepto';
                    }
                    return null;
                  },
                ),
                SpeechDictationHint(controller: _conceptDictation),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 600;
                    final fieldWidth = wide
                        ? (constraints.maxWidth - 12) / 2
                        : constraints.maxWidth;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: fieldWidth,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFormField(
                                controller: _amountController,
                                focusNode: _amountFocusNode,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Monto',
                                ),
                                onFieldSubmitted: (_) =>
                                    _categoryFocusNode.requestFocus(),
                                validator: (value) {
                                  final parsed = _parseInt(value);
                                  if (parsed <= 0) {
                                    return 'Ingresa un monto valido';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: fieldWidth,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFormField(
                                controller: _categoryController,
                                focusNode: _categoryFocusNode,
                                textInputAction: TextInputAction.done,
                                decoration: InputDecoration(
                                  labelText: 'Categoria (opcional)',
                                  suffixIcon: SpeechDictationActionButton(
                                    controller: _categoryDictation,
                                    textController: _categoryController,
                                    tooltip: 'Dictar categoria',
                                  ),
                                ),
                                onFieldSubmitted: (_) => _save(store),
                              ),
                              SpeechDictationHint(
                                controller: _categoryDictation,
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                BpcPanel(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Fecha y hora',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Text(formatDateTimeShort(_dateTime)),
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: _pickDateTime,
                        child: const Text('Cambiar'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 520;
                    final saveButton = FilledButton.icon(
                      onPressed: _saving ? null : () => _save(store),
                      style: compact
                          ? FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                            )
                          : null,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_rounded),
                      label: Text(_saving ? 'Guardando' : 'Guardar gasto'),
                    );

                    if (compact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          saveButton,
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: _saving
                                ? null
                                : () => Navigator.of(context).pop(),
                            child: const Text('Cancelar'),
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        const Spacer(),
                        TextButton(
                          onPressed: _saving
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 12),
                        saveButton,
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dateTime,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) {
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime),
    );
    if (time == null || !mounted) {
      return;
    }
    setState(() {
      _dateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _save(CommerceStore store) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await store.recordExpense(
        concept: _conceptController.text,
        amountPesos: _parseInt(_amountController.text),
        category: _categoryController.text.trim().isEmpty
            ? 'General'
            : _categoryController.text.trim(),
        createdAt: _dateTime,
      );
      if (!mounted) {
        return;
      }
      messenger.hideCurrentSnackBar();
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Gasto guardado. Caja actualizada.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text(userFacingErrorMessage(error))),
      );
    }
  }

  int _parseInt(String? value) {
    final normalized = (value ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (normalized.isEmpty) {
      return 0;
    }
    return int.tryParse(normalized) ?? 0;
  }
}
