import 'dart:io';

import 'atomic_file_writer_contract.dart';
import 'atomic_file_writer_posix.dart';
import 'atomic_file_writer_windows.dart';

AtomicFileWriter createAtomicFileWriter({AtomicWriteCutPointHook? onCutPoint}) {
  if (Platform.isWindows) {
    return WindowsAtomicFileWriter(onCutPoint: onCutPoint);
  }
  return PosixAtomicFileWriter(onCutPoint: onCutPoint);
}
