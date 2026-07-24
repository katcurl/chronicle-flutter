enum AtomicWriteCutPoint {
  afterTempWrite,
  afterTempFsync,
  beforeReplace,
  afterReplace,
}

typedef AtomicWriteCutPointHook = void Function(AtomicWriteCutPoint cutPoint);

abstract interface class AtomicFileWriter {
  Future<void> replace(String targetPath, List<int> bytes);

  /// Atomically moves an already flushed file over [targetPath].
  ///
  /// The source must be on the same filesystem as the target. It is consumed
  /// only when the replacement succeeds.
  Future<void> replaceFile(String targetPath, String sourcePath);
}
