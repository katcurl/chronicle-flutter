import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'atomic_file_writer_contract.dart';

final class PosixAtomicFileWriter implements AtomicFileWriter {
  PosixAtomicFileWriter({AtomicWriteCutPointHook? onCutPoint})
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
      await temporary.rename(target.path);
      _fsyncDirectory(target.parent.path);
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
    await source.rename(target.path);
    _fsyncDirectory(target.parent.path);
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
}

typedef _OpenNative = Int32 Function(Pointer<Utf8> path, Int32 flags);
typedef _OpenDart = int Function(Pointer<Utf8> path, int flags);
typedef _FsyncNative = Int32 Function(Int32 descriptor);
typedef _FsyncDart = int Function(int descriptor);
typedef _CloseNative = Int32 Function(Int32 descriptor);
typedef _CloseDart = int Function(int descriptor);

void _fsyncDirectory(String directoryPath) {
  final libc = DynamicLibrary.process();
  final open = libc.lookupFunction<_OpenNative, _OpenDart>('open');
  final fsync = libc.lookupFunction<_FsyncNative, _FsyncDart>('fsync');
  final close = libc.lookupFunction<_CloseNative, _CloseDart>('close');
  using((arena) {
    final descriptor = open(directoryPath.toNativeUtf8(allocator: arena), 0);
    if (descriptor < 0) {
      throw FileSystemException(
        'Could not open parent directory for fsync.',
        directoryPath,
      );
    }
    try {
      if (fsync(descriptor) != 0) {
        throw FileSystemException(
          'Could not fsync parent directory.',
          directoryPath,
        );
      }
    } finally {
      close(descriptor);
    }
  });
}
