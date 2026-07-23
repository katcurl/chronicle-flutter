export 'clipboard_image_reader_stub.dart'
    if (dart.library.io) 'clipboard_image_reader_io.dart';

String clipboardImageFileName(DateTime timestamp) {
  String twoDigits(int value) => value.toString().padLeft(2, '0');

  final local = timestamp.toLocal();
  return 'clipboard-image-'
      '${local.year.toString().padLeft(4, '0')}'
      '${twoDigits(local.month)}'
      '${twoDigits(local.day)}-'
      '${twoDigits(local.hour)}'
      '${twoDigits(local.minute)}'
      '${twoDigits(local.second)}.png';
}
