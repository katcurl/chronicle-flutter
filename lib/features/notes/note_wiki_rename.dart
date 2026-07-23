import '../../models/app_models.dart';
import 'note_document.dart';
import 'note_wiki_link_syntax.dart';

enum NoteWikiLinkIssueKind { missing, ambiguous }

class NoteWikiLinkIssue {
  const NoteWikiLinkIssue({
    required this.sourceNoteId,
    required this.sourceTitle,
    required this.rawTarget,
    required this.snippet,
    required this.kind,
    this.candidateNoteIds = const <String>[],
  });

  final String sourceNoteId;
  final String sourceTitle;
  final String rawTarget;
  final String snippet;
  final NoteWikiLinkIssueKind kind;
  final List<String> candidateNoteIds;
}

class NoteWikiRenameOccurrence {
  const NoteWikiRenameOccurrence({
    required this.rawTarget,
    required this.snippet,
  });

  final String rawTarget;
  final String snippet;
}

class NoteWikiRenameSourceChange {
  const NoteWikiRenameSourceChange({
    required this.sourceNoteId,
    required this.sourceTitle,
    required this.previousBody,
    required this.updatedBody,
    required this.occurrences,
  });

  final String sourceNoteId;
  final String sourceTitle;
  final String previousBody;
  final String updatedBody;
  final List<NoteWikiRenameOccurrence> occurrences;

  int get occurrenceCount => occurrences.length;
}

class NoteWikiRenamePlan {
  const NoteWikiRenamePlan({
    required this.targetNoteId,
    required this.oldTitle,
    required this.newTitle,
    required this.sourceChanges,
    required this.skippedAmbiguousOccurrences,
  });

  final String targetNoteId;
  final String oldTitle;
  final String newTitle;
  final List<NoteWikiRenameSourceChange> sourceChanges;
  final int skippedAmbiguousOccurrences;

  int get changedNoteCount => sourceChanges.length;
  int get occurrenceCount => sourceChanges.fold<int>(
    0,
    (total, change) => total + change.occurrenceCount,
  );
  bool get hasChanges => sourceChanges.isNotEmpty;
  bool get requiresReview =>
      hasChanges || skippedAmbiguousOccurrences > 0;
}

class NoteWikiSnapshot {
  const NoteWikiSnapshot({
    required this.noteId,
    required this.title,
    required this.body,
  });

  final String noteId;
  final String title;
  final String body;
}

class NoteWikiRenameUndo {
  const NoteWikiRenameUndo({
    required this.snapshots,
    required this.appliedSnapshots,
  });

  final List<NoteWikiSnapshot> snapshots;
  final List<NoteWikiSnapshot> appliedSnapshots;
}

class NoteWikiRenamePlanner {
  const NoteWikiRenamePlanner._();

  static NoteWikiRenamePlan build({
    required Note target,
    required String newTitle,
    required Iterable<Note> notes,
    required Note? Function(Note source, String rawTarget) resolveTarget,
    required List<Note> Function(Note source, String rawTarget)
    targetCandidates,
  }) {
    final trimmedTitle = newTitle.trim();
    final exactTarget = NoteWikiTarget.exactId(target.id);
    final sourceChanges = <NoteWikiRenameSourceChange>[];
    var skippedAmbiguousOccurrences = 0;

    for (final source in notes) {
      final parsed = NoteDocument.parse(source.body);
      final references = NoteWikiLinkSyntax.all(parsed.content).toList();
      if (references.isEmpty) {
        continue;
      }

      var updatedContent = parsed.content;
      final occurrences = <NoteWikiRenameOccurrence>[];
      for (final reference in references.reversed) {
        final resolved = resolveTarget(source, reference.target);
        if (resolved?.id != target.id) {
          final candidates = targetCandidates(source, reference.target);
          if (candidates.any((candidate) => candidate.id == target.id)) {
            skippedAmbiguousOccurrences += 1;
          }
          continue;
        }

        final explicitLabel = reference.label?.trim();
        final replacementLabel =
            explicitLabel == null || explicitLabel.isEmpty
                ? trimmedTitle
                : _sameTitle(explicitLabel, target.title)
                ? trimmedTitle
                : explicitLabel;
        occurrences.add(
          NoteWikiRenameOccurrence(
            rawTarget: reference.target,
            snippet: NoteWikiLinkSyntax.snippetForReference(
              parsed.content,
              reference,
            ),
          ),
        );
        updatedContent = NoteWikiLinkSyntax.replaceTarget(
          updatedContent,
          reference,
          target: exactTarget,
          label: replacementLabel,
        );
      }

      if (occurrences.isEmpty || updatedContent == parsed.content) {
        continue;
      }
      sourceChanges.add(
        NoteWikiRenameSourceChange(
          sourceNoteId: source.id,
          sourceTitle: source.title,
          previousBody: source.body,
          updatedBody: NoteDocument.replaceContent(source.body, updatedContent),
          occurrences: List<NoteWikiRenameOccurrence>.unmodifiable(
            occurrences.reversed,
          ),
        ),
      );
    }

    sourceChanges.sort(
      (left, right) => left.sourceTitle.toLowerCase().compareTo(
        right.sourceTitle.toLowerCase(),
      ),
    );
    return NoteWikiRenamePlan(
      targetNoteId: target.id,
      oldTitle: target.title,
      newTitle: trimmedTitle,
      sourceChanges: List<NoteWikiRenameSourceChange>.unmodifiable(
        sourceChanges,
      ),
      skippedAmbiguousOccurrences: skippedAmbiguousOccurrences,
    );
  }

  static List<NoteWikiLinkIssue> findIssues({
    required Iterable<Note> notes,
    required Note? Function(Note source, String rawTarget) resolveTarget,
    required List<Note> Function(Note source, String rawTarget)
    targetCandidates,
  }) {
    final issues = <NoteWikiLinkIssue>[];
    final seen = <String>{};
    for (final source in notes) {
      final content = NoteDocument.parse(source.body).content;
      for (final reference in NoteWikiLinkSyntax.all(content)) {
        if (resolveTarget(source, reference.target) != null) {
          continue;
        }
        final key = '${source.id}\u0000${reference.target.toLowerCase()}';
        if (!seen.add(key)) {
          continue;
        }
        final candidates = targetCandidates(source, reference.target);
        issues.add(
          NoteWikiLinkIssue(
            sourceNoteId: source.id,
            sourceTitle: source.title,
            rawTarget: reference.target,
            snippet: NoteWikiLinkSyntax.snippetForReference(
              content,
              reference,
            ),
            kind:
                candidates.isEmpty
                    ? NoteWikiLinkIssueKind.missing
                    : NoteWikiLinkIssueKind.ambiguous,
            candidateNoteIds: List<String>.unmodifiable(
              candidates.map((candidate) => candidate.id),
            ),
          ),
        );
      }
    }
    issues.sort((left, right) {
      final kindCompare = left.kind.index.compareTo(right.kind.index);
      if (kindCompare != 0) return kindCompare;
      return left.sourceTitle.toLowerCase().compareTo(
        right.sourceTitle.toLowerCase(),
      );
    });
    return List<NoteWikiLinkIssue>.unmodifiable(issues);
  }

  static bool _sameTitle(String left, String right) {
    return left.trim().toLowerCase() == right.trim().toLowerCase();
  }
}
