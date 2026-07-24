final class VaultRevision {
  VaultRevision(Map<String, String?> sha256ByPath)
    : sha256ByPath = Map<String, String?>.unmodifiable(sha256ByPath);

  VaultRevision.empty() : sha256ByPath = const <String, String?>{};

  final Map<String, String?> sha256ByPath;

  bool hasSameContentAs(VaultRevision other) {
    if (sha256ByPath.length != other.sha256ByPath.length) {
      return false;
    }
    for (final entry in sha256ByPath.entries) {
      if (!other.sha256ByPath.containsKey(entry.key) ||
          other.sha256ByPath[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }

  Set<String> changedPathsComparedWith(VaultRevision other) {
    final paths = <String>{...sha256ByPath.keys, ...other.sha256ByPath.keys};
    return {
      for (final path in paths)
        if (!sha256ByPath.containsKey(path) ||
            !other.sha256ByPath.containsKey(path) ||
            sha256ByPath[path] != other.sha256ByPath[path])
          path,
    };
  }
}

final class VaultChangedSinceScanException implements Exception {
  VaultChangedSinceScanException({required Set<String> changedPaths})
    : changedPaths = Set<String>.unmodifiable(changedPaths);

  final Set<String> changedPaths;

  @override
  String toString() {
    final paths = changedPaths.toList()..sort();
    return 'Vault изменился после сканирования: ${paths.join(', ')}';
  }
}
