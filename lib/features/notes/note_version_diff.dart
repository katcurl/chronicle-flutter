enum NoteVersionDiffKind { unchanged, added, removed }

class NoteVersionDiffLine {
  const NoteVersionDiffLine({
    required this.kind,
    required this.text,
    this.oldLineNumber,
    this.newLineNumber,
  });

  final NoteVersionDiffKind kind;
  final String text;
  final int? oldLineNumber;
  final int? newLineNumber;
}

class NoteVersionDiff {
  const NoteVersionDiff({
    required this.lines,
    required this.addedLineCount,
    required this.removedLineCount,
    required this.unchangedLineCount,
    required this.isApproximate,
  });

  final List<NoteVersionDiffLine> lines;
  final int addedLineCount;
  final int removedLineCount;
  final int unchangedLineCount;

  /// Large documents use a prefix/suffix comparison instead of a quadratic
  /// longest-common-subsequence matrix. No content is omitted, but moved lines
  /// inside the changed middle are represented as removals plus additions.
  final bool isApproximate;

  bool get hasChanges => addedLineCount > 0 || removedLineCount > 0;

  static NoteVersionDiff compare(
    String older,
    String newer, {
    int maxMatrixCells = 250000,
  }) {
    final oldLines = _splitLines(older);
    final newLines = _splitLines(newer);
    final matrixCells = oldLines.length * newLines.length;
    if (matrixCells > maxMatrixCells) {
      return _compareLarge(oldLines, newLines);
    }
    return _compareExact(oldLines, newLines);
  }

  static NoteVersionDiff _compareExact(
    List<String> oldLines,
    List<String> newLines,
  ) {
    final rows = oldLines.length + 1;
    final columns = newLines.length + 1;
    final matrix = List<List<int>>.generate(
      rows,
      (_) => List<int>.filled(columns, 0, growable: false),
      growable: false,
    );

    for (var oldIndex = oldLines.length - 1; oldIndex >= 0; oldIndex -= 1) {
      for (
        var newIndex = newLines.length - 1;
        newIndex >= 0;
        newIndex -= 1
      ) {
        if (oldLines[oldIndex] == newLines[newIndex]) {
          matrix[oldIndex][newIndex] = matrix[oldIndex + 1][newIndex + 1] + 1;
        } else {
          final removeScore = matrix[oldIndex + 1][newIndex];
          final addScore = matrix[oldIndex][newIndex + 1];
          matrix[oldIndex][newIndex] =
              removeScore >= addScore ? removeScore : addScore;
        }
      }
    }

    final lines = <NoteVersionDiffLine>[];
    var oldIndex = 0;
    var newIndex = 0;
    var added = 0;
    var removed = 0;
    var unchanged = 0;

    while (oldIndex < oldLines.length || newIndex < newLines.length) {
      if (oldIndex < oldLines.length &&
          newIndex < newLines.length &&
          oldLines[oldIndex] == newLines[newIndex]) {
        lines.add(
          NoteVersionDiffLine(
            kind: NoteVersionDiffKind.unchanged,
            text: oldLines[oldIndex],
            oldLineNumber: oldIndex + 1,
            newLineNumber: newIndex + 1,
          ),
        );
        oldIndex += 1;
        newIndex += 1;
        unchanged += 1;
        continue;
      }

      final shouldRemove =
          oldIndex < oldLines.length &&
          (newIndex >= newLines.length ||
              matrix[oldIndex + 1][newIndex] >=
                  matrix[oldIndex][newIndex + 1]);
      if (shouldRemove) {
        lines.add(
          NoteVersionDiffLine(
            kind: NoteVersionDiffKind.removed,
            text: oldLines[oldIndex],
            oldLineNumber: oldIndex + 1,
          ),
        );
        oldIndex += 1;
        removed += 1;
      } else {
        lines.add(
          NoteVersionDiffLine(
            kind: NoteVersionDiffKind.added,
            text: newLines[newIndex],
            newLineNumber: newIndex + 1,
          ),
        );
        newIndex += 1;
        added += 1;
      }
    }

    return NoteVersionDiff(
      lines: List<NoteVersionDiffLine>.unmodifiable(lines),
      addedLineCount: added,
      removedLineCount: removed,
      unchangedLineCount: unchanged,
      isApproximate: false,
    );
  }

  static NoteVersionDiff _compareLarge(
    List<String> oldLines,
    List<String> newLines,
  ) {
    var prefixLength = 0;
    while (prefixLength < oldLines.length &&
        prefixLength < newLines.length &&
        oldLines[prefixLength] == newLines[prefixLength]) {
      prefixLength += 1;
    }

    var suffixLength = 0;
    while (suffixLength < oldLines.length - prefixLength &&
        suffixLength < newLines.length - prefixLength &&
        oldLines[oldLines.length - suffixLength - 1] ==
            newLines[newLines.length - suffixLength - 1]) {
      suffixLength += 1;
    }

    final lines = <NoteVersionDiffLine>[];
    for (var index = 0; index < prefixLength; index += 1) {
      lines.add(
        NoteVersionDiffLine(
          kind: NoteVersionDiffKind.unchanged,
          text: oldLines[index],
          oldLineNumber: index + 1,
          newLineNumber: index + 1,
        ),
      );
    }

    final oldMiddleEnd = oldLines.length - suffixLength;
    for (var index = prefixLength; index < oldMiddleEnd; index += 1) {
      lines.add(
        NoteVersionDiffLine(
          kind: NoteVersionDiffKind.removed,
          text: oldLines[index],
          oldLineNumber: index + 1,
        ),
      );
    }

    final newMiddleEnd = newLines.length - suffixLength;
    for (var index = prefixLength; index < newMiddleEnd; index += 1) {
      lines.add(
        NoteVersionDiffLine(
          kind: NoteVersionDiffKind.added,
          text: newLines[index],
          newLineNumber: index + 1,
        ),
      );
    }

    for (var offset = suffixLength; offset > 0; offset -= 1) {
      final oldIndex = oldLines.length - offset;
      final newIndex = newLines.length - offset;
      lines.add(
        NoteVersionDiffLine(
          kind: NoteVersionDiffKind.unchanged,
          text: oldLines[oldIndex],
          oldLineNumber: oldIndex + 1,
          newLineNumber: newIndex + 1,
        ),
      );
    }

    final removed = oldMiddleEnd - prefixLength;
    final added = newMiddleEnd - prefixLength;
    return NoteVersionDiff(
      lines: List<NoteVersionDiffLine>.unmodifiable(lines),
      addedLineCount: added,
      removedLineCount: removed,
      unchangedLineCount: prefixLength + suffixLength,
      isApproximate: true,
    );
  }

  static List<String> _splitLines(String value) {
    final normalized = value.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    return normalized.split('\n');
  }
}
