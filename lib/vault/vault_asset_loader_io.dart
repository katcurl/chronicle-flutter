import 'dart:io';
import 'dart:typed_data';

import 'managed_path_resolver.dart';

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
  try {
    final target = await createManagedPathResolver().resolveExisting(
      rootPath,
      relative,
    );
    return File(target).readAsBytes();
  } on FileSystemException catch (error) {
    final code = error.osError?.errorCode;
    if (code == 2 || code == 3) {
      return null;
    }
    rethrow;
  }
}
