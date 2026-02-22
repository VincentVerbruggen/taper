import 'package:drift/drift.dart' show Value;
// hide Threshold to avoid clash with our database's Threshold model.
// Flutter's Threshold is a Curve subclass from animations — not used here.
import 'package:flutter/material.dart' hide Threshold;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:taper/data/database.dart';
import 'package:taper/data/decay_model.dart';
import 'package:taper/providers/database_providers.dart';
import 'package:taper/screens/trackables/add_taper_plan_screen.dart';
import 'package:taper/screens/trackables/widgets/color_palette_selector.dart';
import 'package:taper/utils/validation.dart';

/// EditTrackableScreen = the form for editing an existing trackable.
///
/// Like a Laravel edit form (trackables/{id}/edit.blade.php) that receives
/// the existing model via route-model binding:
///   public function edit(Trackable $trackable) { ... }
///
/// Contains ALL trackable settings in one place:
///   - Name, Unit (text fields)
///   - Decay model dropdown (None / Exponential / Linear)
///   - Half-life (shown only for exponential)
///   - Elimination rate (shown only for linear)
///   - Visibility toggle (show/hide in log form)
///   - Delete button with confirmation
class EditTrackableScreen extends ConsumerStatefulWidget {
  /// The trackable to edit — passed in like route-model binding.
  final Trackable trackable;

  const EditTrackableScreen({super.key, required this.trackable});

  @override
  ConsumerState<EditTrackableScreen> createState() =>
      _EditTrackableScreenState();
}

class _EditTrackableScreenState extends ConsumerState<EditTrackableScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _unitController;
  late final TextEditingController _halfLifeController;
  late final TextEditingController _eliminationRateController;
  late final TextEditingController _absorptionMinutesController;

  /// The currently selected decay model in the dropdown.
  /// Drives which parameter field (half-life vs elimination rate) is shown.
  late DecayModel _selectedDecayModel;

  /// Selected color from the palette (ARGB int).
  /// Initialized from the trackable's current color.
  late int _selectedColor;

  /// Whether this trackable appears in the log form dropdown.
  late bool _isVisible;

  /// Whether to show a cumulative intake staircase on the decay chart.
  late bool _showCumulativeLine;

  /// Tracks whether the user has attempted to save.
  /// Controls when "Required" errors appear on empty required fields.
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill all form fields from the existing trackable.
    // Like old() in Laravel Blade — populates inputs with previous values.
    _nameController = TextEditingController(text: widget.trackable.name);
    _unitController = TextEditingController(text: widget.trackable.unit);
    _halfLifeController = TextEditingController(
      text: widget.trackable.halfLifeHours?.toString() ?? '',
    );
    _eliminationRateController = TextEditingController(
      text: widget.trackable.eliminationRate?.toString() ?? '',
    );
    _absorptionMinutesController = TextEditingController(
      text: widget.trackable.absorptionMinutes?.toString() ?? '',
    );
    _selectedDecayModel = DecayModel.fromString(widget.trackable.decayModel);
    _selectedColor = widget.trackable.color;
    _isVisible = widget.trackable.isVisible;
    _showCumulativeLine = widget.trackable.showCumulativeLine;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _unitController.dispose();
    _halfLifeController.dispose();
    _eliminationRateController.dispose();
    _absorptionMinutesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch all trackables to check for duplicate names.
    // Exclude the current trackable so renaming to the same name works fine.
    // Like: Rule::unique('trackables', 'name')->ignore($trackable->id)
    final existingTrackableNames = ref.watch(trackablesProvider)
        .value
        ?.where((t) => t.id != widget.trackable.id)
        .map((t) => t.name)
        .toList() ?? [];

    return Scaffold(
      // AppBar gives us the back button for free.
      appBar: AppBar(
        title: const Text('Edit Trackable'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Trackable name ---
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Trackable name',
                border: const OutlineInputBorder(),
                errorText: _submitted && _nameController.text.trim().isEmpty
                    ? 'Required'
                    : duplicateNameError(_nameController.text, existingTrackableNames),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _save(existingTrackableNames),
            ),

            const SizedBox(height: 16),

            // --- Unit ---
            TextField(
              controller: _unitController,
              decoration: const InputDecoration(
                labelText: 'Unit',
                hintText: 'mg',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            // --- Color picker ---
            // Shows the 10 palette colors as tappable circles.
            // Like a color swatch picker in a design tool.
            Text(
              'Color',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            ColorPaletteSelector(
              selectedColor: _selectedColor,
              onColorSelected: (color) => setState(() => _selectedColor = color),
            ),

            const SizedBox(height: 24),

            // --- Presets section ---
            // Named dose shortcuts for this trackable (e.g., "Espresso" = 90 mg).
            // Users can add/delete presets here; they appear as chips in the
            // quick-add dialog and Add Dose screen for one-tap dose entry.
            // Like a "has-many" relationship section in a Laravel edit form.
            _buildPresetsSection(),

            const SizedBox(height: 24),

            // --- Thresholds section ---
            // Named horizontal reference lines for the decay chart (e.g.,
            // "Daily max" = 400 mg). Like thresholds/limits in a monitoring dashboard.
            _buildThresholdsSection(),

            const SizedBox(height: 24),

            // --- Taper plans section ---
            // Gradual reduction schedules. Shows plan history with status labels,
            // retry (copies params to new plan), and delete.
            // Like a "has-many" relationship section showing order history.
            _buildTaperPlansSection(),

            const SizedBox(height: 16),

            // --- Decay model dropdown ---
            // Like a <select> in HTML. DropdownButtonFormField integrates with
            // Material 3's InputDecoration for consistent styling.
            DropdownButtonFormField<DecayModel>(
              initialValue: _selectedDecayModel,
              decoration: const InputDecoration(
                labelText: 'Decay model',
                border: OutlineInputBorder(),
              ),
              items: DecayModel.values.map((model) {
                return DropdownMenuItem<DecayModel>(
                  value: model,
                  child: Text(model.displayName),
                );
              }).toList(),
              onChanged: (model) {
                if (model != null) {
                  setState(() => _selectedDecayModel = model);
                }
              },
            ),

            const SizedBox(height: 16),

            // --- Half-life field (only for exponential) ---
            // AnimatedSize smoothly collapses/expands when the decay model changes.
            // Like a v-show transition in Vue.
            if (_selectedDecayModel == DecayModel.exponential)
              TextField(
                controller: _halfLifeController,
                decoration: InputDecoration(
                  labelText: 'Half-life (hours)',
                  hintText: 'e.g. 5.0',
                  border: const OutlineInputBorder(),
                  errorText: numericFieldError(_halfLifeController.text),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                ],
                onChanged: (_) => setState(() {}),
              ),

            // --- Elimination rate field (only for linear) ---
            if (_selectedDecayModel == DecayModel.linear)
              TextField(
                controller: _eliminationRateController,
                decoration: InputDecoration(
                  labelText: 'Elimination rate (${_unitController.text.trim().isEmpty ? 'units' : _unitController.text.trim()}/hour)',
                  hintText: 'e.g. 9.0',
                  border: const OutlineInputBorder(),
                  errorText: numericFieldError(_eliminationRateController.text),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                ],
                onChanged: (_) => setState(() {}),
              ),

            // --- Absorption time field (for exponential and linear) ---
            // How long it takes for the dose to be fully absorbed before decay
            // begins. Creates a linear ramp-up phase on the curve.
            // Like an "onset delay" — e.g., a capsule takes 30 min to dissolve.
            if (_selectedDecayModel != DecayModel.none) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _absorptionMinutesController,
                decoration: InputDecoration(
                  labelText: 'Absorption time (minutes)',
                  hintText: 'e.g. 30 (optional)',
                  border: const OutlineInputBorder(),
                  errorText: numericFieldError(_absorptionMinutesController.text),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                ],
                onChanged: (_) => setState(() {}),
              ),
            ],

            // --- Cumulative intake toggle (only for trackables with decay) ---
            // Shows a staircase line on the chart representing total consumed today.
            // Like toggling a "show overlay" option on a chart in a dashboard.
            if (_selectedDecayModel != DecayModel.none) ...[
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Show cumulative intake'),
                subtitle: const Text(
                  'Overlay a line showing total consumed today',
                ),
                value: _showCumulativeLine,
                onChanged: (value) =>
                    setState(() => _showCumulativeLine = value),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
            ],

            // Spacing only needed if a parameter field was shown above.
            if (_selectedDecayModel != DecayModel.none)
              const SizedBox(height: 16),

            // --- Visibility toggle ---
            // SwitchListTile = a list tile with an integrated switch on the right.
            // Like a toggle component in a settings screen.
            SwitchListTile(
              title: const Text('Visible in log form'),
              subtitle: const Text('Hidden trackables keep their data but don\'t appear in the dropdown'),
              value: _isVisible,
              onChanged: (value) => setState(() => _isVisible = value),
              // Gives the tile a card-like outline to match other form fields.
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // --- Save button ---
            // Always enabled — shows errors on press instead of silently disabling.
            FilledButton.icon(
              onPressed: () => _save(existingTrackableNames),
              icon: const Icon(Icons.check),
              label: const Text('Save Changes'),
            ),

            const SizedBox(height: 12),

            // --- Delete button ---
            // Error-colored outline button at the bottom. Opens a confirmation
            // dialog before actually deleting. Like a "danger zone" section.
            OutlinedButton.icon(
              onPressed: _confirmDelete,
              icon: Icon(Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error),
              label: Text(
                'Delete Trackable',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the presets management section: header, list, and "Add Preset" button.
  ///
  /// Watches presetsProvider reactively — adding/deleting a preset in the DB
  /// immediately updates this list without any manual setState() calls.
  /// Like a Livewire component that auto-refreshes when its query changes.
  Widget _buildPresetsSection() {
    final presetsAsync = ref.watch(presetsProvider(widget.trackable.id));
    final unit = _unitController.text.trim().isEmpty
        ? 'mg'
        : _unitController.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Presets',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),

        // Show the list of existing presets (or nothing if loading/empty).
        presetsAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (e, s) => Text('Error loading presets: $e'),
          data: (presetsList) {
            if (presetsList.isEmpty) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'No presets yet',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            }
            // Each preset = a Card-wrapped ListTile with name, amount, and delete button.
            // Tapping the tile opens an edit dialog (same as dose log entries).
            // Like a simple CRUD list inside a parent form.
            return Column(
              children: presetsList.map((preset) {
                // For edit dialog: exclude this preset's name so renaming to
                // the same name doesn't trigger a duplicate error.
                final otherPresetNames = presetsList
                    .where((p) => p.id != preset.id)
                    .map((p) => p.name)
                    .toList();
                final shape = RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                );
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2.0),
                  child: Card(
                    shape: shape,
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      customBorder: shape,
                      onTap: () => _showEditPresetDialog(preset, otherPresetNames),
                      child: ListTile(
                        title: Text(preset.name),
                        subtitle: Text('${preset.amount.toStringAsFixed(0)} ${_unitController.text.trim().isEmpty ? 'mg' : _unitController.text.trim()}'),
                        // Trailing delete button — removes the preset immediately.
                        // Presets are lightweight; no confirmation dialog needed.
                        trailing: IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          onPressed: () {
                            ref.read(databaseProvider).deletePreset(preset.id);
                          },
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),

        // "Add Preset" button — opens a dialog with name + amount fields.
        // Pass all existing names so the dialog can check for duplicates.
        TextButton.icon(
          onPressed: () => _showAddPresetDialog(
            presetsAsync.value?.map((p) => p.name).toList() ?? [],
          ),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add Preset'),
        ),
      ],
    );
  }

  /// Shows a dialog to add a new preset (name + amount).
  /// Like a nested create form that inserts into a related table.
  /// [existingNames] = names of other presets in this trackable, for duplicate checking.
  void _showAddPresetDialog(List<String> existingNames) {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    // Tracks whether the user has attempted to save.
    // Before this, empty fields don't show "Required" (avoids error spam on open).
    // After tapping Add, empty required fields light up with errors.
    // Like Laravel's $errors bag — only populated after form submission.
    var submitted = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        // StatefulBuilder so the dialog can rebuild when text changes —
        // needed for live errorText updates on the amount and name fields.
        // Like using Alpine.js x-data inside a Blade modal.
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Compute error text: "Required" takes priority over other validators.
            final nameError = submitted && nameController.text.trim().isEmpty
                ? 'Required'
                : duplicateNameError(nameController.text, existingNames);
            final amountError = submitted && amountController.text.trim().isEmpty
                ? 'Required'
                : numericFieldError(amountController.text);

            return AlertDialog(
              title: const Text('Add Preset'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Name',
                      hintText: 'e.g. Espresso',
                      border: const OutlineInputBorder(),
                      errorText: nameError,
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      suffixText: _unitController.text.trim().isEmpty
                          ? 'mg'
                          : _unitController.text.trim(),
                      border: const OutlineInputBorder(),
                      errorText: amountError,
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                    ],
                    onChanged: (_) => setDialogState(() {}),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    final amount = double.tryParse(amountController.text.trim());
                    // If validation fails, mark as submitted so error messages
                    // appear, then rebuild the dialog to show them.
                    if (name.isEmpty ||
                        duplicateNameError(name, existingNames) != null ||
                        amount == null || amount <= 0) {
                      submitted = true;
                      setDialogState(() {});
                      return;
                    }
                    ref.read(databaseProvider).insertPreset(
                      widget.trackable.id,
                      name,
                      amount,
                    );
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Shows a dialog to edit an existing preset's name and/or amount.
  /// Pre-fills with the current values — like editing a row in a related table.
  /// Same layout as _showAddPresetDialog but calls updatePreset() instead of insert.
  /// [existingNames] = names of OTHER presets (excluding this one), for duplicate checking.
  void _showEditPresetDialog(Preset preset, List<String> existingNames) {
    final nameController = TextEditingController(text: preset.name);
    final amountController = TextEditingController(
      text: preset.amount.toStringAsFixed(
        preset.amount == preset.amount.roundToDouble() ? 0 : 1,
      ),
    );
    var submitted = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final nameError = submitted && nameController.text.trim().isEmpty
                ? 'Required'
                : duplicateNameError(nameController.text, existingNames);
            final amountError = submitted && amountController.text.trim().isEmpty
                ? 'Required'
                : numericFieldError(amountController.text);

            return AlertDialog(
              title: const Text('Edit Preset'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Name',
                      border: const OutlineInputBorder(),
                      errorText: nameError,
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      suffixText: _unitController.text.trim().isEmpty
                          ? 'mg'
                          : _unitController.text.trim(),
                      border: const OutlineInputBorder(),
                      errorText: amountError,
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                    ],
                    onChanged: (_) => setDialogState(() {}),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    final amount = double.tryParse(amountController.text.trim());
                    if (name.isEmpty ||
                        duplicateNameError(name, existingNames) != null ||
                        amount == null || amount <= 0) {
                      submitted = true;
                      setDialogState(() {});
                      return;
                    }
                    ref.read(databaseProvider).updatePreset(
                      preset.id,
                      name: name,
                      amount: amount,
                    );
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Builds the thresholds management section: header, list, and "Add Threshold" button.
  ///
  /// Same pattern as the presets section — a reactively-updating list with
  /// inline delete and an add button that opens a dialog.
  /// Thresholds appear as dashed horizontal lines on the decay chart.
  Widget _buildThresholdsSection() {
    final thresholdsAsync = ref.watch(thresholdsProvider(widget.trackable.id));
    final unit = _unitController.text.trim().isEmpty
        ? 'mg'
        : _unitController.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Thresholds',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),

        // Show the list of existing thresholds (or nothing if loading/empty).
        thresholdsAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (e, s) => Text('Error loading thresholds: $e'),
          data: (thresholdsList) {
            if (thresholdsList.isEmpty) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'No thresholds yet',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            }
            // Each threshold = a Card-wrapped ListTile with name, amount, and delete button.
            // Tapping the tile opens an edit dialog (same pattern as presets).
            return Column(
              children: thresholdsList.map((threshold) {
                // For edit dialog: exclude this threshold's name.
                final otherThresholdNames = thresholdsList
                    .where((t) => t.id != threshold.id)
                    .map((t) => t.name)
                    .toList();
                final shape = RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                );
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2.0),
                  child: Card(
                    shape: shape,
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      customBorder: shape,
                      onTap: () => _showEditThresholdDialog(threshold, otherThresholdNames),
                      child: ListTile(
                        title: Text(threshold.name),
                        subtitle: Text('${threshold.amount.toStringAsFixed(0)} ${_unitController.text.trim().isEmpty ? 'mg' : _unitController.text.trim()}'),
                        trailing: IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          onPressed: () {
                            ref.read(databaseProvider).deleteThreshold(threshold.id);
                          },
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),

        // "Add Threshold" button — opens a dialog with name + amount fields.
        // Pass all existing names so the dialog can check for duplicates.
        TextButton.icon(
          onPressed: () => _showAddThresholdDialog(
            thresholdsAsync.value?.map((t) => t.name).toList() ?? [],
          ),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add Threshold'),
        ),
      ],
    );
  }

  /// Builds the taper plans management section: header, plan list, and "New Taper Plan" button.
  ///
  /// Watches taperPlansProvider reactively — adding/deleting a plan in the DB
  /// immediately updates this list. Shows status labels:
  ///   - "Active" = isActive && !ended
  ///   - "Completed" = isActive && ended (still active, past end date)
  ///   - "Superseded" = !isActive (replaced by a newer plan)
  ///
  /// Like an order history section in a customer edit form.
  Widget _buildTaperPlansSection() {
    final plansAsync = ref.watch(taperPlansProvider(widget.trackable.id));
    final unit = _unitController.text.trim().isEmpty
        ? 'mg'
        : _unitController.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Taper Plans',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),

        // Show the list of existing plans (or "No taper plans yet" if empty).
        plansAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (e, s) => Text('Error loading taper plans: $e'),
          data: (plansList) {
            if (plansList.isEmpty) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'No taper plans yet',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            }
            // Each plan = a Card with title ("400 → 100 mg"), subtitle (dates + status),
            // and trailing icons for Retry and Delete.
            return Column(
              children: plansList.map((plan) {
                final status = _taperPlanStatus(plan);
                final shape = RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                );
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2.0),
                  child: Card(
                    shape: shape,
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      // "400 → 100 mg" — start and target amounts.
                      title: Text(
                        '${plan.startAmount.toStringAsFixed(0)} → ${plan.targetAmount.toStringAsFixed(0)} $unit',
                      ),
                      // Date range + status chip. Format: "Feb 1 – Mar 15 · Active"
                      subtitle: Text(
                        '${_formatDate(plan.startDate)} – ${_formatDate(plan.endDate)} · $status',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Retry: copies this plan's params into a new plan form.
                          // Like duplicating an order with updated dates.
                          IconButton(
                            icon: const Icon(Icons.replay, size: 20),
                            tooltip: 'Retry with same settings',
                            onPressed: () => _retryTaperPlan(plan),
                          ),
                          // Delete: removes the plan.
                          IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              size: 20,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            tooltip: 'Delete plan',
                            onPressed: () {
                              ref.read(databaseProvider).deleteTaperPlan(plan.id);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),

        // "New Taper Plan" button — navigates to the creation form.
        TextButton.icon(
          onPressed: () => _addTaperPlan(),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('New Taper Plan'),
        ),
      ],
    );
  }

  /// Determines the status label for a taper plan.
  ///
  /// - Active: isActive == true (could be before start, in progress, or maintenance)
  /// - Completed: isActive == false AND endDate is in the past
  /// - Superseded: isActive == false AND endDate is NOT in the past
  ///   (replaced by a newer plan before it finished)
  String _taperPlanStatus(TaperPlan plan) {
    if (plan.isActive) return 'Active';
    // If inactive, check if the plan ran to completion or was superseded early.
    if (plan.endDate.isBefore(DateTime.now())) return 'Completed';
    return 'Superseded';
  }

  /// Format a date as "Feb 1" or "Mar 15" for compact display in plan cards.
  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  /// Navigate to AddTaperPlanScreen pre-filled with an old plan's amounts (Retry flow).
  /// Like duplicating a record in a CRUD list.
  void _retryTaperPlan(TaperPlan plan) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddTaperPlanScreen(
          trackable: widget.trackable,
          initialStartAmount: plan.startAmount,
          initialTargetAmount: plan.targetAmount,
        ),
      ),
    );
  }

  /// Navigate to AddTaperPlanScreen with empty defaults.
  void _addTaperPlan() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddTaperPlanScreen(trackable: widget.trackable),
      ),
    );
  }

  /// Shows a dialog to add a new threshold (name + amount).
  /// Like a nested create form that inserts into a related table.
  /// [existingNames] = names of other thresholds in this trackable, for duplicate checking.
  void _showAddThresholdDialog(List<String> existingNames) {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    var submitted = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final nameError = submitted && nameController.text.trim().isEmpty
                ? 'Required'
                : duplicateNameError(nameController.text, existingNames);
            final amountError = submitted && amountController.text.trim().isEmpty
                ? 'Required'
                : numericFieldError(amountController.text);

            return AlertDialog(
              title: const Text('Add Threshold'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Name',
                      hintText: 'e.g. Daily max',
                      border: const OutlineInputBorder(),
                      errorText: nameError,
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      suffixText: _unitController.text.trim().isEmpty
                          ? 'mg'
                          : _unitController.text.trim(),
                      border: const OutlineInputBorder(),
                      errorText: amountError,
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                    ],
                    onChanged: (_) => setDialogState(() {}),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    final amount = double.tryParse(amountController.text.trim());
                    if (name.isEmpty ||
                        duplicateNameError(name, existingNames) != null ||
                        amount == null || amount <= 0) {
                      submitted = true;
                      setDialogState(() {});
                      return;
                    }
                    ref.read(databaseProvider).insertThreshold(
                      widget.trackable.id,
                      name,
                      amount,
                    );
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Shows a dialog to edit an existing threshold's name and/or amount.
  /// Pre-fills with the current values — like editing a row in a related table.
  /// Same layout as _showAddThresholdDialog but calls updateThreshold() instead of insert.
  /// [existingNames] = names of OTHER thresholds (excluding this one), for duplicate checking.
  void _showEditThresholdDialog(Threshold threshold, List<String> existingNames) {
    final nameController = TextEditingController(text: threshold.name);
    final amountController = TextEditingController(
      text: threshold.amount.toStringAsFixed(
        threshold.amount == threshold.amount.roundToDouble() ? 0 : 1,
      ),
    );
    var submitted = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final nameError = submitted && nameController.text.trim().isEmpty
                ? 'Required'
                : duplicateNameError(nameController.text, existingNames);
            final amountError = submitted && amountController.text.trim().isEmpty
                ? 'Required'
                : numericFieldError(amountController.text);

            return AlertDialog(
              title: const Text('Edit Threshold'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Name',
                      border: const OutlineInputBorder(),
                      errorText: nameError,
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      suffixText: _unitController.text.trim().isEmpty
                          ? 'mg'
                          : _unitController.text.trim(),
                      border: const OutlineInputBorder(),
                      errorText: amountError,
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                    ],
                    onChanged: (_) => setDialogState(() {}),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    final amount = double.tryParse(amountController.text.trim());
                    if (name.isEmpty ||
                        duplicateNameError(name, existingNames) != null ||
                        amount == null || amount <= 0) {
                      submitted = true;
                      setDialogState(() {});
                      return;
                    }
                    ref.read(databaseProvider).updateThreshold(
                      threshold.id,
                      name: name,
                      amount: amount,
                    );
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  bool _saving = false;

  /// Update the trackable in the database and pop back to the list.
  /// Clears irrelevant fields when switching decay models:
  ///   - Switching to linear → clears halfLifeHours
  ///   - Switching to exponential → clears eliminationRate
  ///   - Switching to none → clears both
  void _save(List<String> existingNames) async {
    if (_saving) return;
    final name = _nameController.text.trim();
    if (name.isEmpty || duplicateNameError(name, existingNames) != null) {
      _submitted = true;
      setState(() {});
      return;
    }
    _saving = true;

    final unit = _unitController.text.trim().isEmpty
        ? 'mg'
        : _unitController.text.trim();

    // Parse the parameter field for the selected decay model.
    // Irrelevant fields are explicitly set to null so old values don't linger.
    final halfLife = _selectedDecayModel == DecayModel.exponential
        ? double.tryParse(_halfLifeController.text.trim())
        : null;
    final eliminationRate = _selectedDecayModel == DecayModel.linear
        ? double.tryParse(_eliminationRateController.text.trim())
        : null;

    // Absorption time is relevant for both exponential and linear models.
    // When decay model is "none", clear it (no decay = no absorption phase).
    final absorptionMinutes = _selectedDecayModel != DecayModel.none
        ? double.tryParse(_absorptionMinutesController.text.trim())
        : null;

    await ref.read(databaseProvider).updateTrackable(
      widget.trackable.id,
      name: name,
      unit: unit,
      decayModel: _selectedDecayModel.toDbString(),
      halfLifeHours: Value(halfLife),
      eliminationRate: Value(eliminationRate),
      absorptionMinutes: Value(absorptionMinutes),
      isVisible: Value(_isVisible),
      color: Value(_selectedColor),
      // Clear cumulative line when switching to no-decay model (irrelevant).
      showCumulativeLine: Value(
        _selectedDecayModel != DecayModel.none ? _showCumulativeLine : false,
      ),
    );

    _saving = false;
    if (mounted) {
      Navigator.pop(context);
    }
  }

  /// Show a confirmation dialog before deleting.
  /// AlertDialog with "Cancel" and "Delete" actions — the "Delete" button
  /// uses error color to signal destructive intent. Like a modal confirm
  /// in JavaScript: if (confirm('Delete?')) { ... }
  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Trackable'),
          content: Text(
            'Delete "${widget.trackable.name}" and all its dose history? This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext); // Close dialog.
                _delete();
              },
              child: Text(
                'Delete',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Delete the trackable and pop back to the list.
  void _delete() async {
    await ref.read(databaseProvider).deleteTrackable(widget.trackable.id);
    if (mounted) {
      Navigator.pop(context); // Pop the edit screen.
    }
  }
}
