import 'package:drift/drift.dart' show Value;
// hide Threshold to avoid clash with our database's Threshold model.
// Flutter's Threshold is a Curve subclass from animations — not used here.
import 'package:flutter/material.dart' hide Threshold;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:taper/data/database.dart';
import 'package:taper/data/decay_model.dart';
import 'package:taper/providers/database_providers.dart';
import 'package:taper/screens/trackables/presets_screen.dart';
import 'package:taper/screens/trackables/reminders_screen.dart';
import 'package:taper/screens/trackables/taper_plans_screen.dart';
import 'package:taper/screens/trackables/thresholds_screen.dart';
import 'package:taper/screens/trackables/widgets/color_palette_selector.dart';
import 'package:taper/utils/validation.dart';

/// EditTrackableScreen = the form for editing an existing trackable.
///
/// Like a Laravel edit form (trackables/{id}/edit.blade.php) that receives
/// the existing model via route-model binding:
///   public function edit(Trackable $trackable) { ... }
///
/// Contains core trackable settings:
///   - Name, Unit (text fields)
///   - Color picker
///   - Navigation tiles to sub-screens (Presets, Thresholds, Taper Plans, Reminders)
///   - Decay model dropdown (None / Exponential / Linear)
///   - Half-life (shown only for exponential)
///   - Elimination rate (shown only for linear)
///   - Visibility toggle (show/hide in log form)
///   - Delete button with confirmation
///
/// Sub-sections (presets, thresholds, taper plans, reminders) are extracted
/// to dedicated screens accessed via navigation tiles. This follows the
/// standard mobile pattern (like iOS Settings) to keep the edit form
/// manageable as features grow.
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

    // Watch related data counts for navigation tile summaries.
    // These are lightweight stream providers that update reactively.
    final presetsAsync = ref.watch(presetsProvider(widget.trackable.id));
    final thresholdsAsync = ref.watch(thresholdsProvider(widget.trackable.id));
    final plansAsync = ref.watch(taperPlansProvider(widget.trackable.id));
    final remindersAsync = ref.watch(remindersProvider(widget.trackable.id));

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

            // --- Related data sections (click-through to sub-screens) ---
            // Each tile navigates to a dedicated full-screen for managing
            // that section's data. Like iOS Settings rows that push to
            // detail screens. Count summaries update reactively.
            _buildNavTile(
              icon: Icons.bolt,
              label: 'Presets',
              summary: _countSummary(presetsAsync, 'preset'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PresetsScreen(trackable: widget.trackable),
                ),
              ),
            ),
            _buildNavTile(
              icon: Icons.horizontal_rule,
              label: 'Thresholds',
              summary: _countSummary(thresholdsAsync, 'threshold'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ThresholdsScreen(trackable: widget.trackable),
                ),
              ),
            ),
            _buildNavTile(
              icon: Icons.trending_down,
              label: 'Taper Plans',
              summary: _taperPlanSummary(plansAsync),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TaperPlansScreen(trackable: widget.trackable),
                ),
              ),
            ),
            _buildNavTile(
              icon: Icons.notifications_outlined,
              label: 'Reminders',
              summary: _countSummary(remindersAsync, 'reminder'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RemindersScreen(trackable: widget.trackable),
                ),
              ),
            ),

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

            // --- Duplicate button ---
            // Creates a "Copy of X" with the same settings.
            // Like Laravel's replicate(): $copy = $trackable->replicate()
            OutlinedButton.icon(
              onPressed: _duplicate,
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Duplicate Trackable'),
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

  /// Builds a navigation tile that pushes to a sub-screen.
  ///
  /// Follows the iOS Settings pattern: leading icon, title, subtitle with
  /// a count/summary, and a trailing chevron indicating navigation.
  /// Like a <a> tag styled as a list item in a sidebar navigation.
  Widget _buildNavTile({
    required IconData icon,
    required String label,
    required String summary,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(summary),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
      // Compact vertical padding since these tiles are grouped together.
      visualDensity: VisualDensity.compact,
    );
  }

  /// Generates a summary string like "3 presets" or "No presets" from an async list.
  /// Handles loading/error states gracefully with a "..." fallback.
  String _countSummary<T>(AsyncValue<List<T>> asyncList, String singular) {
    return asyncList.when(
      loading: () => '...',
      error: (_, _) => '...',
      data: (list) {
        if (list.isEmpty) return 'No ${singular}s';
        if (list.length == 1) return '1 $singular';
        return '${list.length} ${singular}s';
      },
    );
  }

  /// Generates a summary for the taper plans tile.
  /// Shows "1 active plan" if there's an active plan, otherwise the count.
  String _taperPlanSummary(AsyncValue<List<TaperPlan>> plansAsync) {
    return plansAsync.when(
      loading: () => '...',
      error: (_, _) => '...',
      data: (plans) {
        if (plans.isEmpty) return 'No plans';
        final activePlan = plans.where((p) => p.isActive).firstOrNull;
        if (activePlan != null) return '1 active plan';
        return '${plans.length} plan${plans.length == 1 ? '' : 's'}';
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

  /// Duplicate this trackable: creates "Copy of X" with the same settings.
  /// Like Laravel's replicate(): $copy = $trackable->replicate()->fill([...])
  void _duplicate() async {
    final db = ref.read(databaseProvider);
    await db.insertTrackable(
      'Copy of ${widget.trackable.name}',
      unit: widget.trackable.unit,
      halfLifeHours: widget.trackable.halfLifeHours,
      decayModel: widget.trackable.decayModel,
      eliminationRate: widget.trackable.eliminationRate,
      absorptionMinutes: widget.trackable.absorptionMinutes,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          showCloseIcon: true,
          content: Text('Created "Copy of ${widget.trackable.name}"'),
        ),
      );
    }
  }

  /// Delete the trackable and pop back to the list.
  void _delete() async {
    await ref.read(databaseProvider).deleteTrackable(widget.trackable.id);
    if (mounted) {
      Navigator.pop(context); // Pop the edit screen.
    }
  }
}
