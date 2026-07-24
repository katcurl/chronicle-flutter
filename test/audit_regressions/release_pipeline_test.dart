import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _readNormalized(String path) {
  return File(path)
      .readAsStringSync()
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n');
}

void main() {
  const buildAndroidPath = '.github/workflows/build-apk.yml';
  const buildWindowsPath = '.github/workflows/build-windows.yml';
  const releasePath = '.github/workflows/release.yml';

  test('all third-party actions are pinned to immutable commits', () {
    for (final path in [buildAndroidPath, buildWindowsPath, releasePath]) {
      final workflow = _readNormalized(path);
      final actionReferences = RegExp(
        r'uses:\s*([^\s@]+)@([^\s#]+)',
      ).allMatches(workflow);

      expect(actionReferences, isNotEmpty, reason: '$path has no actions');

      for (final match in actionReferences) {
        final action = match.group(1)!;
        final reference = match.group(2)!;

        if (action.startsWith('./')) {
          continue;
        }

        expect(
          reference,
          matches(RegExp(r'^[0-9a-f]{40}$')),
          reason: '$path uses mutable action reference $action@$reference',
        );
      }
    }
  });

  test('ordinary Android builds cannot read signing secrets', () {
    final workflow = _readNormalized(buildAndroidPath);

    expect(workflow, isNot(contains('secrets.')));
    expect(workflow, isNot(contains('feature/data-core')));
    expect(workflow, isNot(contains('flutter create')));
    expect(workflow, contains('Verify artifacts are unsigned'));
    expect(workflow, contains('app-release.apk'));
    expect(workflow, contains('app-release.aab'));
  });

  test('Windows artifact is portable, JNI-free, and smoke-tested', () {
    final workflow = _readNormalized(buildWindowsPath);

    expect(workflow, isNot(contains('secrets.')));
    expect(workflow, contains('msvcp140.dll'));
    expect(workflow, contains('vcruntime140.dll'));
    expect(workflow, contains('vcruntime140_1.dll'));
    expect(workflow, contains('dartjni.dll'));
    expect(workflow, contains('MainWindowHandle'));
    expect(workflow, contains('windows-x64-unsigned.zip'));
  });

  test('tag-only release signs in a protected environment and attests', () {
    final workflow = _readNormalized(releasePath);

    expect(workflow, contains("tags:\n      - 'v*'"));
    expect(workflow, contains('environment: release-signing'));
    expect(workflow, contains(r'"$APKSIGNER" sign'));
    expect(workflow, contains('jarsigner'));
    expect(workflow, contains('Get-AuthenticodeSignature'));
    expect(workflow, contains('actions/attest@'));
    expect(workflow, contains('sbom-path:'));
    expect(workflow, contains('subject-checksums:'));
  });

  test('release support files are tracked', () {
    expect(File('tool/generate_spdx_sbom.dart').existsSync(), isTrue);
    expect(File('SECURITY.md').existsSync(), isTrue);

    final pubspec = _readNormalized('pubspec.yaml');
    expect(pubspec, contains('path_provider_android: 2.2.23'));

    final lockfile = _readNormalized('pubspec.lock');
    expect(lockfile, isNot(contains('\n  jni:')));
    expect(lockfile, isNot(contains('\n  jni_flutter:')));
  });
}