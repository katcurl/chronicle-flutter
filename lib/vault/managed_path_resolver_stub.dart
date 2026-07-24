abstract interface class ManagedPathResolver {
  Future<String> resolveExisting(String rootPath, String relativePath);

  Future<String> resolveForWrite(String rootPath, String relativePath);
}

ManagedPathResolver createManagedPathResolver() =>
    const _UnsupportedManagedPathResolver();

final class _UnsupportedManagedPathResolver implements ManagedPathResolver {
  const _UnsupportedManagedPathResolver();

  @override
  Future<String> resolveExisting(String rootPath, String relativePath) {
    throw UnsupportedError('Managed filesystem paths are unavailable.');
  }

  @override
  Future<String> resolveForWrite(String rootPath, String relativePath) {
    throw UnsupportedError('Managed filesystem paths are unavailable.');
  }
}
