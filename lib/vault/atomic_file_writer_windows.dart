import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:win32/win32.dart';

import 'atomic_file_writer_contract.dart';

final class WindowsAtomicFileWriter implements AtomicFileWriter {
  WindowsAtomicFileWriter({AtomicWriteCutPointHook? onCutPoint})
    : _onCutPoint = onCutPoint;

  final AtomicWriteCutPointHook? _onCutPoint;
  final Uuid _uuid = const Uuid();

  @override
  Future<void> replace(String targetPath, List<int> bytes) async {
    final target = File(targetPath);
    await target.parent.create(recursive: true);
    await _removeStaleTemps(target);
    final temporary = File(
      p.join(
        target.parent.path,
        '.${p.basename(target.path)}.${_uuid.v4()}.tmp',
      ),
    );
    RandomAccessFile? handle;
    try {
      handle = await temporary.open(mode: FileMode.writeOnly);
      await handle.writeFrom(bytes);
      _onCutPoint?.call(AtomicWriteCutPoint.afterTempWrite);
      await handle.flush();
      _onCutPoint?.call(AtomicWriteCutPoint.afterTempFsync);
      await handle.close();
      handle = null;
      _onCutPoint?.call(AtomicWriteCutPoint.beforeReplace);
      _replaceWithWriteThrough(temporary.path, target.path);
      _onCutPoint?.call(AtomicWriteCutPoint.afterReplace);
    } on Object {
      if (handle != null) {
        await handle.close();
      }
      if (await temporary.exists()) {
        await temporary.delete();
      }
      rethrow;
    }
  }

  @override
  Future<void> replaceFile(String targetPath, String sourcePath) async {
    final target = File(targetPath);
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw FileSystemException(
        'Atomic replacement source is missing.',
        sourcePath,
      );
    }
    if (p.dirname(source.absolute.path) != p.dirname(target.absolute.path)) {
      throw FileSystemException(
        'Atomic replacement source must share the target directory.',
        sourcePath,
      );
    }
    await target.parent.create(recursive: true);
    _onCutPoint?.call(AtomicWriteCutPoint.beforeReplace);
    _replaceWithWriteThrough(source.path, target.path);
    _onCutPoint?.call(AtomicWriteCutPoint.afterReplace);
  }

  Future<void> _removeStaleTemps(File target) async {
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    final name = RegExp.escape(p.basename(target.path));
    final pattern = RegExp(
      '^\\.$name\\.[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-'
      '[89ab][0-9a-f]{3}-[0-9a-f]{12}\\.tmp\$',
      caseSensitive: false,
    );
    await for (final entity in target.parent.list(followLinks: false)) {
      if (entity is! File || !pattern.hasMatch(p.basename(entity.path))) {
        continue;
      }
      final stat = await entity.stat();
      if (stat.modified.isBefore(cutoff)) {
        await entity.delete();
      }
    }
  }

  void _replaceWithWriteThrough(String sourcePath, String targetPath) {
    using((arena) {
      final result = MoveFileEx(
        sourcePath.toPcwstr(allocator: arena),
        targetPath.toPcwstr(allocator: arena),
        MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH,
      );
      if (!result.value) {
        throw FileSystemException(
          'MoveFileExW could not atomically replace the target.',
          targetPath,
          OSError('Win32 error ${result.error}', result.error),
        );
      }
    });
  }
}
