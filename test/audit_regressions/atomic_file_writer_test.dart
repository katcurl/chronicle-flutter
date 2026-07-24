import 'dart:io';
import 'dart:typed_data';

import 'package:chronicle/vault/atomic_file_writer.dart';
import 'package:chronicle/vault/vault_backend.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory directory;
  late File target;
  final oldBytes = Uint8List.fromList('complete-old'.codeUnits);
  final newBytes = Uint8List.fromList('complete-new'.codeUnits);

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'chronicle-atomic-write-',
    );
    target = File('${directory.path}/note.md');
    await target.writeAsBytes(oldBytes, flush: true);
  });

  tearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  for (final cutPoint in AtomicWriteCutPoint.values) {
    test('cut at ${cutPoint.name} leaves one complete target', () async {
      final writer = createAtomicFileWriter(
        onCutPoint: (current) {
          if (current == cutPoint) {
            throw StateError('simulated crash at ${current.name}');
          }
        },
      );

      await expectLater(
        writer.replace(target.path, newBytes),
        throwsA(isA<StateError>()),
      );

      expect(await target.exists(), isTrue);
      final actual = await target.readAsBytes();
      expect(<List<int>>[oldBytes, newBytes], contains(equals(actual)));
      if (cutPoint == AtomicWriteCutPoint.afterReplace) {
        expect(actual, newBytes);
      } else {
        expect(actual, oldBytes);
      }
      expect(
        directory.listSync().whereType<File>().where(
          (file) => file.path.endsWith('.tmp'),
        ),
        isEmpty,
      );
    });
  }

  test('successful replace publishes all new bytes', () async {
    final writer = createAtomicFileWriter();

    await writer.replace(target.path, newBytes);

    expect(await target.readAsBytes(), newBytes);
  });

  test('Vault publishes metadata last', () async {
    final recording = _RecordingAtomicFileWriter();
    final backend = VaultBackend(atomicFileWriter: recording);

    await backend.writeFiles(
      rootPath: directory.path,
      files: const {
        'manifest.json': 'manifest',
        '.chronicle/vault-index.json': 'index',
        'Notes/note.md': 'note',
      },
      staleManagedPaths: const {},
    );

    final canonicalRoot = await directory.resolveSymbolicLinks();
    expect(
      recording.paths.map(
        (path) =>
            p.relative(path, from: canonicalRoot).replaceAll(p.separator, '/'),
      ),
      ['Notes/note.md', '.chronicle/vault-index.json', 'manifest.json'],
    );
  });

  test('Vault retains stale files when a replacement fails', () async {
    final stale = File('${directory.path}/Notes/stale.md');
    await stale.parent.create(recursive: true);
    await stale.writeAsString('keep');
    final recording = _RecordingAtomicFileWriter(failAtCall: 1);
    final backend = VaultBackend(atomicFileWriter: recording);

    await expectLater(
      backend.writeFiles(
        rootPath: directory.path,
        files: const {'Notes/new.md': 'new'},
        staleManagedPaths: const {'Notes/stale.md'},
      ),
      throwsA(isA<FileSystemException>()),
    );

    expect(await stale.readAsString(), 'keep');
  });
}

final class _RecordingAtomicFileWriter implements AtomicFileWriter {
  _RecordingAtomicFileWriter({this.failAtCall});

  final int? failAtCall;
  final List<String> paths = [];
  final AtomicFileWriter _delegate = createAtomicFileWriter();

  @override
  Future<void> replace(String targetPath, List<int> bytes) async {
    paths.add(targetPath);
    if (paths.length == failAtCall) {
      throw FileSystemException('simulated replacement failure', targetPath);
    }
    await _delegate.replace(targetPath, bytes);
  }

  @override
  Future<void> replaceFile(String targetPath, String sourcePath) async {
    paths.add(targetPath);
    if (paths.length == failAtCall) {
      throw StateError('Injected atomic replacement failure.');
    }
    await _delegate.replaceFile(targetPath, sourcePath);
  }
}
