import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taper/data/database.dart';
import 'package:taper/providers/database_providers.dart';
import 'package:taper/utils/validation.dart';

class AddTargetScreen extends ConsumerStatefulWidget {
  final Trackable trackable;

  const AddTargetScreen({super.key, required this.trackable});

  @override
  ConsumerState<AddTargetScreen> createState() => _AddTargetScreenState();
}

class _AddTargetScreenState extends ConsumerState<AddTargetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  TimeOfDay? _selectedTime;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      // Force 24h input regardless of OS locale so target-time entry matches
      // the rest of the app's HH:mm data model and avoids AM/PM ambiguity.
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (time != null) {
      setState(() {
        _selectedTime = time;
      });
    }
  }

  void _save() {
    if (_formKey.currentState!.validate() && _selectedTime != null) {
      final db = ref.read(databaseProvider);
      db.insertTarget(
        trackableId: widget.trackable.id,
        name: _nameController.text,
        amount: double.parse(_amountController.text),
        time: _format24h(_selectedTime!),
      );
      Navigator.of(context).pop();
    } else if (_selectedTime == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a time')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Target'),
        actions: [IconButton(icon: const Icon(Icons.check), onPressed: _save)],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g., Bedtime',
              ),
              validator: (value) =>
                  value == null || value.isEmpty ? 'Please enter a name' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: 'Amount',
                suffixText: widget.trackable.unit,
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an amount';
                }
                // Reuse the shared numeric validator so this screen stays in sync
                // with the rest of the app's number parsing/edge-case handling.
                // This avoids stale one-off checks when validation rules evolve.
                final amountError = numericFieldError(value);
                if (amountError != null) {
                  return amountError;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Time'),
              // Keep display in 24h to mirror stored format and picker mode.
              subtitle: Text(
                _selectedTime == null ? 'Not set' : _format24h(_selectedTime!),
              ),
              trailing: const Icon(Icons.edit),
              onTap: _pickTime,
            ),
          ],
        ),
      ),
    );
  }

  /// Format TimeOfDay as HH:mm (24-hour), e.g. "07:05", "18:30".
  ///
  /// Keeping this local avoids locale-dependent formatting drift.
  String _format24h(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
