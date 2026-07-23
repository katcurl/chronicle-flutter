import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

Future<Uint8List?> loadVaultAttachment(
  String rootPath,
  String markdownPath,
) async {
  if (rootPath.trim().isEmpty) {
    return null;
  }
  final decoded = Uri.decodeComponent(markdownPath).replaceAll('\\', '/');
  final marker = decoded.toLowerCase().indexOf('attachments/');
  if (marker < 0) {
    return null;
  }
  final relative = decoded.substring(marker);
  final root = p.normalize(p.absolute(p.join(rootPath, 'Attachments')));
  final target = p.normalize(
    p.absolute(p.join(rootPath, relative.replaceAll('/', p.separator))),
  );
  if (target != root && !p.isWithin(root, target)) {
    return null;
  }
  final file = File(target);
  if (!await file.exists()) {
    return null;
  }
  return file.readAsBytes();
}
