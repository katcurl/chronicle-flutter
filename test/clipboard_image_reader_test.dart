import 'package:chronicle/platform/clipboard_image_reader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('clipboard image filename is stable and sortable', () {
    final value = clipboardImageFileName(DateTime(2026, 7, 22, 13, 4, 5));

    expect(value, 'clipboard-image-20260722-130405.png');
  });
}
