enum AtomicWriteCutPoint {
  afterTempWrite,
  afterTempFsync,
  beforeReplace,
  afterReplace,
}

typedef AtomicWriteCutPointHook = void Function(AtomicWriteCutPoint cutPoint);

abstract interface class AtomicFileWriter {
  Future<void> replace(String targetPath, List<int> bytes);
}
