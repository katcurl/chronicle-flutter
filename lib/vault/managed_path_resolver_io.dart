import 'dart:io';

import 'package:path/path.dart' as p;

abstract interface class ManagedPathResolver {
  Future<String> resolveExisting(String rootPath, String relativePath);

  Future<String> resolveForWrite(String rootPath, String relativePath);
}

ManagedPathResolver createManagedPathResolver() => IoManagedPathResolver();

final class IoManagedPathResolver implements ManagedPathResolver {
  @override
  Future<String> resolveExisting(String rootPath, String relativePath) async {
    final segments = _validatedSegments(relativePath);
    final canonicalRoot = await _canonicalRoot(rootPath, create: false);
    final lexicalTarget = p.joinAll([canonicalRoot, ...segments]);
    final type = await FileSystemEntity.type(lexicalTarget, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      throw FileSystemException(
        'Managed path does not exist.',
        lexicalTarget,
        const OSError('No such file or directory', 2),
      );
    }
    final canonicalTarget = await _resolveEntity(lexicalTarget, type);
    _requireWithin(canonicalRoot, canonicalTarget, relativePath);
    return canonicalTarget;
  }

  @override
  Future<String> resolveForWrite(String rootPath, String relativePath) async {
    final segments = _validatedSegments(relativePath);
    final canonicalRoot = await _canonicalRoot(rootPath, create: true);
    var canonicalParent = canonicalRoot;

    for (final segment in segments.take(segments.length - 1)) {
      final candidate = p.join(canonicalParent, segment);
      var type = await FileSystemEntity.type(candidate, followLinks: false);
      if (type == FileSystemEntityType.notFound) {
        await Directory(candidate).create();
        type = FileSystemEntityType.directory;
      }
      if (type == FileSystemEntityType.file) {
        throw FileSystemException(
          'Managed path parent is not a directory.',
          candidate,
        );
      }
      final resolved = await _resolveEntity(candidate, type);
      _requireWithin(canonicalRoot, resolved, relativePath);
      final resolvedType = await FileSystemEntity.type(resolved);
      if (resolvedType != FileSystemEntityType.directory) {
        throw FileSystemException(
          'Managed path parent is not a directory.',
          candidate,
        );
      }
      canonicalParent = resolved;
    }

    final target = p.join(canonicalParent, segments.last);
    final targetType = await FileSystemEntity.type(target, followLinks: false);
    if (targetType == FileSystemEntityType.notFound) {
      _requireWithin(canonicalRoot, target, relativePath);
      return target;
    }
    final canonicalTarget = await _resolveEntity(target, targetType);
    _requireWithin(canonicalRoot, canonicalTarget, relativePath);
    return canonicalTarget;
  }

  List<String> _validatedSegments(String relativePath) {
    if (relativePath.isEmpty ||
        relativePath.contains('\\') ||
        p.posix.isAbsolute(relativePath) ||
        p.windows.isAbsolute(relativePath)) {
      throw FormatException('Unsafe managed path: $relativePath');
    }
    final segments = relativePath.split('/');
    if (segments.any(
      (segment) => segment.isEmpty || segment == '.' || segment == '..',
    )) {
      throw FormatException('Unsafe managed path: $relativePath');
    }
    return segments;
  }

  Future<String> _canonicalRoot(String rootPath, {required bool create}) async {
    final root = Directory(p.normalize(p.absolute(rootPath)));
    if (create) {
      await root.create(recursive: true);
    }
    return root.resolveSymbolicLinks();
  }

  Future<String> _resolveEntity(String path, FileSystemEntityType type) {
    if (type == FileSystemEntityType.directory) {
      return Directory(path).resolveSymbolicLinks();
    }
    if (type == FileSystemEntityType.link) {
      return Link(path).resolveSymbolicLinks();
    }
    return File(path).resolveSymbolicLinks();
  }

  void _requireWithin(
    String canonicalRoot,
    String target,
    String relativePath,
  ) {
    final normalizedTarget = p.normalize(p.absolute(target));
    if (!p.equals(canonicalRoot, normalizedTarget) &&
        !p.isWithin(canonicalRoot, normalizedTarget)) {
      throw FileSystemException(
        'Managed path escapes the configured Vault root: $relativePath',
        normalizedTarget,
      );
    }
  }
}
