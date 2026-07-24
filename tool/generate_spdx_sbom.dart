import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.length != 1) {
    stderr.writeln(
      'Usage: dart run tool/generate_spdx_sbom.dart <output.spdx.json>',
    );
    exitCode = 64;
    return;
  }

  final dependencyResult = await Process.run(
    Platform.resolvedExecutable,
    const ['pub', 'deps', '--json'],
    runInShell: Platform.isWindows,
  );
  if (dependencyResult.exitCode != 0) {
    stderr.write(dependencyResult.stderr);
    exitCode = dependencyResult.exitCode;
    return;
  }

  final dependencyGraph =
      jsonDecode(dependencyResult.stdout as String) as Map<String, dynamic>;
  final rootName = dependencyGraph['root'] as String;
  final packages =
      (dependencyGraph['packages'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .toList()
        ..sort((left, right) {
          final nameOrder = (left['name'] as String).compareTo(
            right['name'] as String,
          );
          if (nameOrder != 0) {
            return nameOrder;
          }
          return (left['version'] as String).compareTo(
            right['version'] as String,
          );
        });

  final packageByName = <String, Map<String, dynamic>>{
    for (final package in packages) package['name'] as String: package,
  };
  final documentSeed = packages
      .map((package) => '${package['name']}@${package['version']}')
      .join('\n');
  final documentDigest = sha256.convert(utf8.encode(documentSeed));

  final output = <String, dynamic>{
    'spdxVersion': 'SPDX-2.3',
    'dataLicense': 'CC0-1.0',
    'SPDXID': 'SPDXRef-DOCUMENT',
    'name': '$rootName dependency SBOM',
    'documentNamespace':
        'https://io.github.katcurl.chronicle/spdx/'
        '$rootName/$documentDigest',
    'creationInfo': {
      'created': _creationTime().toIso8601String(),
      'creators': ['Tool: Chronicle SPDX generator'],
    },
    'packages': [for (final package in packages) _spdxPackage(package)],
    'relationships': [
      {
        'spdxElementId': 'SPDXRef-DOCUMENT',
        'relationshipType': 'DESCRIBES',
        'relatedSpdxElement': _spdxId(packageByName[rootName]!),
      },
      for (final package in packages)
        for (final dependency in (package['dependencies'] as List<dynamic>))
          if (packageByName.containsKey(dependency))
            {
              'spdxElementId': _spdxId(package),
              'relationshipType': 'DEPENDS_ON',
              'relatedSpdxElement': _spdxId(packageByName[dependency]!),
            },
    ],
  };

  final target = File(arguments.single);
  await target.parent.create(recursive: true);
  await target.writeAsString(
    '${const JsonEncoder.withIndent('  ').convert(output)}\n',
    flush: true,
  );
}

Map<String, dynamic> _spdxPackage(Map<String, dynamic> package) {
  final name = package['name'] as String;
  final version = package['version'] as String;
  final source = package['source'] as String;

  return {
    'name': name,
    'SPDXID': _spdxId(package),
    'versionInfo': version,
    'downloadLocation':
        source == 'hosted' ? 'https://pub.dev/packages/$name' : 'NOASSERTION',
    'filesAnalyzed': false,
    'licenseConcluded': 'NOASSERTION',
    'licenseDeclared': 'NOASSERTION',
    'copyrightText': 'NOASSERTION',
    'externalRefs': [
      {
        'referenceCategory': 'PACKAGE-MANAGER',
        'referenceType': 'purl',
        'referenceLocator':
            'pkg:pub/${Uri.encodeComponent(name)}@'
            '${Uri.encodeComponent(version)}',
      },
    ],
  };
}

String _spdxId(Map<String, dynamic> package) {
  final identity = '${package['name']}@${package['version']}';
  final digest = sha256.convert(utf8.encode(identity)).toString();
  return 'SPDXRef-Package-${digest.substring(0, 24)}';
}

DateTime _creationTime() {
  final sourceDateEpoch = Platform.environment['SOURCE_DATE_EPOCH'];
  final epochSeconds = int.tryParse(sourceDateEpoch ?? '');
  if (epochSeconds != null && epochSeconds >= 0) {
    return DateTime.fromMillisecondsSinceEpoch(
      epochSeconds * Duration.millisecondsPerSecond,
      isUtc: true,
    );
  }
  return DateTime.now().toUtc();
}
