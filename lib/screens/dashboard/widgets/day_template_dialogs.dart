import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:taper/data/database.dart';
import 'package:taper/providers/database_providers.dart';
import 'package:taper/utils/validation.dart';

// Dialogs for day templates, opened from the trackable day overview's menu.
//
// Each function shows a dialog and returns what the user chose (or null when
// cancelled) — the screen then does the actual save/apply. Like a modal
// component that emits a result instead of submitting the form itself.

/// What the save dialog decided: the template name, plus the id of an
/// existing template to overwrite (null = create a new one).
typedef SaveTemplateChoice = ({String name, int? overwriteTemplateId});

/// Asks for a template name. If it matches one of [existing]
/// (case-insensitive) the user must confirm overwriting it first.
Future<SaveTemplateChoice?> showSaveTemplateDialog({
  required BuildContext context,
  required List<DayTemplate> existing,
}) {
  final nameController = TextEditingController();
  // Errors only appear after the first Save tap — like Laravel's $errors bag,
  // which is only filled after a submit.
  var submitted = false;

  return showDialog<SaveTemplateChoice>(
    context: context,
    builder: (dialogContext) {
      // StatefulBuilder gives the dialog its own setState so the error text
      // can update without a separate StatefulWidget class.
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final nameError = submitted && nameController.text.trim().isEmpty
              ? 'Required'
              : null;

          Future<void> save() async {
            final name = nameController.text.trim();
            if (name.isEmpty) {
              submitted = true;
              setDialogState(() {});
              return;
            }

            final lower = name.toLowerCase();
            final match = existing
                .where((t) => t.name.toLowerCase() == lower)
                .firstOrNull;
            if (match == null) {
              Navigator.pop(
                dialogContext,
                (name: name, overwriteTemplateId: null),
              );
              return;
            }

            // Nested confirm, stacked on top of this dialog. Cancel returns
            // to the name field so a different name can be typed.
            final overwrite = await _confirm(
              context: dialogContext,
              title: "Overwrite '${match.name}'?",
              message: "Its entries will be replaced with this day's entries.",
              confirmLabel: 'Overwrite',
            );
            // The await may outlive the dialog (e.g. back gesture), so check
            // its context is still mounted before popping with it.
            if (overwrite && dialogContext.mounted) {
              Navigator.pop(
                dialogContext,
                // Keep the existing name's casing — "workday" overwrites
                // "Workday" without renaming it.
                (name: match.name, overwriteTemplateId: match.id),
              );
            }
          }

          return AlertDialog(
            title: const Text('Save day as template'),
            content: TextField(
              controller: nameController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Template name',
                hintText: 'e.g. Workday',
                border: const OutlineInputBorder(),
                errorText: nameError,
              ),
              onChanged: (_) => setDialogState(() {}),
              onSubmitted: (_) => save(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              // Never disabled — validation happens on press (CLAUDE.md rule).
              TextButton(onPressed: save, child: const Text('Save')),
            ],
          );
        },
      );
    },
  );
}

/// Asks for a new name for [template]. [otherNames] are the names of the
/// trackable's other templates, for the duplicate check.
Future<String?> showRenameTemplateDialog({
  required BuildContext context,
  required DayTemplate template,
  required List<String> otherNames,
}) {
  final nameController = TextEditingController(text: template.name);
  var submitted = false;

  return showDialog<String>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          // "Required" only after a save attempt; duplicates are flagged live.
          final nameError = submitted && nameController.text.trim().isEmpty
              ? 'Required'
              : duplicateNameError(nameController.text, otherNames);

          void save() {
            final name = nameController.text.trim();
            if (name.isEmpty || duplicateNameError(name, otherNames) != null) {
              submitted = true;
              setDialogState(() {});
              return;
            }
            Navigator.pop(dialogContext, name);
          }

          return AlertDialog(
            title: const Text('Rename template'),
            content: TextField(
              controller: nameController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Template name',
                border: const OutlineInputBorder(),
                errorText: nameError,
              ),
              onChanged: (_) => setDialogState(() {}),
              onSubmitted: (_) => save(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              TextButton(onPressed: save, child: const Text('Save')),
            ],
          );
        },
      );
    },
  );
}

/// Row menu actions in the apply dialog. An enum (instead of strings) gives
/// the PopupMenuButton its own type, so it can't be confused with the screen's
/// `PopupMenuButton<String>` overflow menu.
enum _TemplateAction { rename, delete }

/// Lists the trackable's templates. Tapping one returns it; each row also has
/// Rename/Delete actions that update the list in place.
Future<DayTemplate?> showApplyTemplateDialog({
  required BuildContext context,
  required int trackableId,
}) {
  return showDialog<DayTemplate>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Apply template'),
        // AlertDialog sizes its content to the intrinsic width, which a
        // ListView doesn't have. double.maxFinite = "as wide as the dialog
        // allows", and shrinkWrap lets the list be only as tall as its rows.
        content: SizedBox(
          width: double.maxFinite,
          // Consumer = a small widget with access to `ref`, so the dialog can
          // watch the provider and rebuild when templates change.
          child: Consumer(
            builder: (context, ref, _) {
              final templatesAsync = ref.watch(
                dayTemplatesProvider(trackableId),
              );
              final db = ref.read(databaseProvider);

              return templatesAsync.when(
                // Fixed-size placeholder instead of a spinner: a spinner
                // animates forever, which would hang widget tests if the
                // query ever failed to emit.
                loading: () => const SizedBox(height: 48),
                error: (error, _) => Text('Could not load templates: $error'),
                data: (templates) {
                  if (templates.isEmpty) {
                    return const Text(
                      "No templates yet. Use 'Save day as template…' to "
                      'create one.',
                    );
                  }

                  return ListView(
                    shrinkWrap: true,
                    children: [
                      for (final item in templates)
                        ListTile(
                          // Stable key per template so a rebuild (after a
                          // rename) doesn't swap a row's open menu to
                          // another template.
                          key: ValueKey(item.template.id),
                          contentPadding: EdgeInsets.zero,
                          title: Text(item.template.name),
                          subtitle: Text(
                            '${item.entryCount} '
                            '${item.entryCount == 1 ? 'entry' : 'entries'}',
                          ),
                          onTap: () =>
                              Navigator.pop(dialogContext, item.template),
                          trailing: PopupMenuButton<_TemplateAction>(
                            tooltip: 'Template actions',
                            onSelected: (action) => _onTemplateAction(
                              action: action,
                              dialogContext: dialogContext,
                              db: db,
                              template: item.template,
                              allTemplates: templates,
                            ),
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: _TemplateAction.rename,
                                child: Text('Rename'),
                              ),
                              PopupMenuItem(
                                value: _TemplateAction.delete,
                                child: Text('Delete'),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
        ],
      );
    },
  );
}

/// Handles Rename/Delete from a template row. Nested dialogs are opened with
/// the apply dialog's context, so they stack on top of it and the list stays
/// open underneath — it refreshes itself via the provider afterwards.
Future<void> _onTemplateAction({
  required _TemplateAction action,
  required BuildContext dialogContext,
  required AppDatabase db,
  required DayTemplate template,
  required List<DayTemplateWithCount> allTemplates,
}) async {
  switch (action) {
    case _TemplateAction.rename:
      final newName = await showRenameTemplateDialog(
        context: dialogContext,
        template: template,
        otherNames: [
          for (final t in allTemplates)
            if (t.template.id != template.id) t.template.name,
        ],
      );
      if (newName != null) await db.renameDayTemplate(template.id, newName);
    case _TemplateAction.delete:
      final confirmed = await _confirm(
        context: dialogContext,
        title: "Delete '${template.name}'?",
        message: 'This removes the template. Days it was applied to are not '
            'changed.',
        confirmLabel: 'Delete',
      );
      if (confirmed) await db.deleteDayTemplate(template.id);
  }
}

/// Small yes/no dialog. Returns true only when [confirmLabel] is tapped.
Future<bool> _confirm({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (confirmContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(confirmContext, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(confirmContext, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  // Dismissing by tapping outside returns null — treat it as "no".
  return result ?? false;
}
