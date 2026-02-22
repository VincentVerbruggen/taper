import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:taper/data/database.dart';
import 'package:taper/providers/database_providers.dart';
import 'package:taper/providers/settings_providers.dart';
import 'package:taper/utils/day_boundary.dart';

/// Form for creating a new taper plan.
///
/// Follows the AddTrackableScreen pattern:
///   - Fields for start/target amounts + start/end dates
///   - "Create Plan" button (always enabled, validates on press)
///   - Optional pre-fill for Retry flow (copies old plan's amounts)
///
/// Plans are immutable — there's no edit screen. To adjust, create
/// a new plan which atomically deactivates the previous one.
///
/// Like a Laravel create form: taper-plans/create.blade.php
class AddTaperPlanScreen extends ConsumerStatefulWidget {
  /// The trackable this plan belongs to (needed for unit display and DB insert).
  final Trackable trackable;

  /// Pre-fill values for the Retry flow — copies an old plan's amounts
  /// so users can quickly create a new plan with adjusted dates.
  final double? initialStartAmount;
  final double? initialTargetAmount;

  const AddTaperPlanScreen({
    super.key,
    required this.trackable,
    this.initialStartAmount,
    this.initialTargetAmount,
  });

  @override
  ConsumerState<AddTaperPlanScreen> createState() =>
      _AddTaperPlanScreenState();
}

class _AddTaperPlanScreenState extends ConsumerState<AddTaperPlanScreen> {
  late final TextEditingController _startAmountController;
  late final TextEditingController _targetAmountController;

  /// Selected start/end dates. Defaults: today's boundary → 4 weeks from today.
  late DateTime _startDate;
  late DateTime _endDate;

  /// Tracks whether the user has attempted to save.
  /// Before this, empty fields don't show "Required" (avoids error spam on open).
  /// After tapping Create, they light up.
  /// Like Laravel's $errors bag — only populated after form submission.
  bool _submitted = false;

  @override
  void initState() {
    super.initState();

    // Pre-fill amounts from Retry flow or leave blank for new plans.
    _startAmountController = TextEditingController(
      text: widget.initialStartAmount?.toStringAsFixed(0) ?? '',
    );
    _targetAmountController = TextEditingController(
      text: widget.initialTargetAmount?.toStringAsFixed(0) ?? '',
    );

    // Default dates: today's boundary → 4 weeks (28 days) from today.
    // Uses the configured boundary hour for consistency with the rest of the app.
    final now = DateTime.now();
    final boundaryHour = 5; // Will be overridden in build() for display
    _startDate = dayBoundary(now, boundaryHour: boundaryHour);
    _endDate = DateTime(
      _startDate.year, _startDate.month, _startDate.day + 28,
      _startDate.hour,
    );
  }

  @override
  void dispose() {
    _startAmountController.dispose();
    _targetAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unit = widget.trackable.unit;

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Taper Plan'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Start amount ---
            // The daily intake target on day 1 of the taper.
            // E.g., "400" for 400 mg/day starting point.
            TextField(
              controller: _startAmountController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Start amount',
                suffixText: unit,
                border: const OutlineInputBorder(),
                // "Required" after submission attempt, otherwise just validate format.
                errorText: _startAmountError(),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                // Only allow digits and decimal point.
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
              ],
              onChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: 16),

            // --- Target amount ---
            // The daily intake target on the final day / maintenance.
            // E.g., "100" for 100 mg/day goal.
            TextField(
              controller: _targetAmountController,
              decoration: InputDecoration(
                labelText: 'Target amount',
                suffixText: unit,
                border: const OutlineInputBorder(),
                errorText: _targetAmountError(),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
              ],
              onChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: 16),

            // --- Start date ---
            // Tappable row that opens a date picker.
            // Like a date input in a web form.
            _buildDateRow(
              label: 'Start date',
              date: _startDate,
              onTap: () => _pickDate(isStart: true),
            ),

            const SizedBox(height: 16),

            // --- End date ---
            _buildDateRow(
              label: 'End date',
              date: _endDate,
              onTap: () => _pickDate(isStart: false),
            ),

            // End date validation error — shown below the date row.
            if (_submitted && !_endDate.isAfter(_startDate))
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 12),
                child: Text(
                  'End date must be after start date',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // --- Create button ---
            // Always enabled — validates on press (like the rest of the app's forms).
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: const Text('Create Plan'),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a tappable date row showing label + formatted date.
  /// Like a read-only input that opens a picker on tap.
  Widget _buildDateRow({
    required String label,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    // Format like "Feb 22, 2026" for readability.
    final dateStr = '${months[date.month - 1]} ${date.day}, ${date.year}';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          // Trailing calendar icon as a visual affordance.
          suffixIcon: const Icon(Icons.calendar_today),
        ),
        child: Text(dateStr),
      ),
    );
  }

  /// Opens a Material date picker and updates the selected start or end date.
  /// Like a date input in a web form that opens a browser-native picker.
  Future<void> _pickDate({required bool isStart}) async {
    final initialDate = isStart ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      // Allow dates from a year ago to a year from now — reasonable range
      // for taper plans. Most plans span weeks to months.
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      // Use the configured boundary hour so the date aligns with app's day logic.
      final boundaryHour = ref.read(dayBoundaryHourProvider);
      final adjusted = DateTime(
        picked.year, picked.month, picked.day, boundaryHour,
      );
      setState(() {
        if (isStart) {
          _startDate = adjusted;
          // Auto-advance end date if it's now before or equal to start.
          // Like a "minimum end date" constraint on a booking form.
          if (!_endDate.isAfter(_startDate)) {
            _endDate = DateTime(
              _startDate.year, _startDate.month, _startDate.day + 28,
              _startDate.hour,
            );
          }
        } else {
          _endDate = adjusted;
        }
      });
    }
  }

  /// Validates the start amount field.
  /// Returns null if valid, error string if invalid.
  String? _startAmountError() {
    final text = _startAmountController.text.trim();
    if (_submitted && text.isEmpty) return 'Required';
    if (text.isEmpty) return null;
    final value = double.tryParse(text);
    if (value == null) return 'Enter a valid number';
    if (value <= 0) return 'Must be greater than zero';
    return null;
  }

  /// Validates the target amount field.
  String? _targetAmountError() {
    final text = _targetAmountController.text.trim();
    if (_submitted && text.isEmpty) return 'Required';
    if (text.isEmpty) return null;
    final value = double.tryParse(text);
    if (value == null) return 'Enter a valid number';
    if (value <= 0) return 'Must be greater than zero';
    return null;
  }

  bool _saving = false;

  /// Validate and save the taper plan.
  ///
  /// On save, the DB's insertTaperPlan() runs in a transaction that
  /// deactivates any existing active plan before inserting the new one.
  /// This ensures only one active plan per trackable at a time.
  void _save() async {
    if (_saving) return;

    final startAmount = double.tryParse(_startAmountController.text.trim());
    final targetAmount = double.tryParse(_targetAmountController.text.trim());

    // If anything is invalid, mark as submitted so all errors show.
    if (startAmount == null || startAmount <= 0 ||
        targetAmount == null || targetAmount <= 0 ||
        !_endDate.isAfter(_startDate)) {
      _submitted = true;
      setState(() {});
      return;
    }

    _saving = true;

    await ref.read(databaseProvider).insertTaperPlan(
      widget.trackable.id,
      startAmount,
      targetAmount,
      _startDate,
      _endDate,
    );

    _saving = false;
    if (mounted) {
      Navigator.pop(context);
    }
  }
}
