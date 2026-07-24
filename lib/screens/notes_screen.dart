import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../features/appearance/app_appearance.dart';
import '../features/notes/custom_note_template_dialog.dart';
import '../features/notes/debounced_text_notifier.dart';
import '../features/notes/note_block_reorder_dialog.dart';
import '../features/notes/note_block_syntax.dart';
import '../features/notes/note_columns_editor_dialog.dart';
import '../features/notes/note_columns_syntax.dart';
import '../features/notes/note_document.dart';
import '../features/notes/note_data_import.dart';
import '../features/notes/note_data_import_dialog.dart';
import '../features/notes/note_data_import_file_service.dart';
import '../features/notes/note_edit_history.dart';
import '../features/notes/note_editor_preferences_store.dart';
import '../features/notes/note_editor_profile.dart';
import '../features/notes/note_editor_profile_dialog.dart';
import '../features/notes/note_export.dart';
import '../features/notes/note_export_dialog.dart';
import '../features/notes/note_export_file_service.dart';
import '../features/notes/note_image_editor_dialog.dart';
import '../features/notes/note_image_syntax.dart';
import '../features/notes/note_link_dialogs.dart';
import '../features/notes/note_link_tools.dart';
import '../features/notes/laboratory_template_dialog.dart';
import '../features/notes/note_graph_screen.dart';
import '../features/notes/note_home_page.dart';
import '../features/notes/note_home_preferences.dart';
import '../features/notes/note_home_preferences_dialog.dart';
import '../features/notes/note_home_preferences_store.dart';
import '../features/notes/research_canvas_screen.dart';
import '../features/notes/note_markdown_view.dart';
import '../features/notes/note_templates.dart';
import '../features/notes/note_version_history_dialog.dart';
import '../features/notes/note_table_syntax.dart';
import '../features/notes/note_toolbar_preferences_store.dart';
import '../features/notes/note_toolbar_profile.dart';
import '../features/notes/note_toolbar_profile_dialog.dart';
import '../features/notes/note_wiki_link_syntax.dart';
import '../features/notes/note_wiki_rename.dart';
import '../features/notes/scientific_object_dialogs.dart';
import '../features/notes/scientific_table_editor_dialog.dart';
import '../features/notes/scientific_reference_syntax.dart';
import '../features/projects/project_appearance_store.dart';
import '../features/projects/project_appearance_widgets.dart';
import '../features/publications/publication_document_export.dart';
import '../features/publications/publication_workspace.dart';
import '../features/publications/publication_workspace_screen.dart';
import '../features/references/citation_syntax.dart';
import '../features/tasks/task_editor_sheet.dart';
import '../models/app_models.dart';
import '../platform/clipboard_image_reader.dart';
import '../services/app_store.dart';
import 'sources_screen.dart';

part 'notes_screen_home.dart';
part 'notes_screen_workspace.dart';
part 'notes_screen_toolbar.dart';
part 'notes_screen_links.dart';
part 'notes_screen_properties.dart';
part 'notes_screen_new_note.dart';

Future<void> _showCustomNoteTemplateManager(
  BuildContext context,
  AppStore store,
) {
  return CustomNoteTemplateManagerDialog.show(
    context,
    templates: store.customNoteTemplates,
    onCreate:
        (draft) => store.createCustomNoteTemplate(
          title: draft.title,
          icon: draft.icon,
          noteType: draft.noteType,
          content: draft.content,
          category: draft.category,
          defaultTags: draft.defaultTags,
        ),
    onUpdate:
        (template, draft) => store.updateCustomNoteTemplate(
          id: template.id,
          title: draft.title,
          icon: draft.icon,
          noteType: draft.noteType,
          content: draft.content,
          category: draft.category,
          defaultTags: draft.defaultTags,
          defaultProperties: template.defaultProperties,
        ),
    onDelete: (template) => store.deleteCustomNoteTemplate(template.id),
    onDuplicate: (template) => store.duplicateCustomNoteTemplate(template.id),
    onImport: store.importCustomNoteTemplates,
  );
}

String _plainSnippet(String markdown) {
  return markdown
      .replaceAll(RegExp(r'```[\s\S]*?```'), ' ')
      .replaceAll(RegExp(r'[#>*_`~\[\]()!-]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String _statusLabel(String status) => switch (status) {
  'review' => 'Проверка',
  'ready' => 'Готово',
  'archived' => 'Архив',
  _ => 'Черновик',
};

String _dateTime(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$day.$month.${value.year} $hour:$minute';
}
