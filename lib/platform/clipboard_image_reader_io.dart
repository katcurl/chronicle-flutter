import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

const _windowsClipboardScript = r'''
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$image = $null
if ([System.Windows.Forms.Clipboard]::ContainsImage()) {
  $image = [System.Windows.Forms.Clipboard]::GetImage()
} elseif ([System.Windows.Forms.Clipboard]::ContainsFileDropList()) {
  $supported = '.png', '.jpg', '.jpeg', '.bmp', '.gif', '.tif', '.tiff'
  $path = [System.Windows.Forms.Clipboard]::GetFileDropList() |
    Where-Object { $supported -contains [System.IO.Path]::GetExtension($_).ToLowerInvariant() } |
    Select-Object -First 1
  if ($null -ne $path) {
    $image = [System.Drawing.Image]::FromFile($path)
  }
}

if ($null -eq $image) {
  exit 0
}

$stream = New-Object System.IO.MemoryStream
try {
  $image.Save($stream, [System.Drawing.Imaging.ImageFormat]::Png)
  $bytes = $stream.ToArray()
  $stdout = [Console]::OpenStandardOutput()
  $stdout.Write($bytes, 0, $bytes.Length)
  $stdout.Flush()
} finally {
  $stream.Dispose()
  $image.Dispose()
}
''';

Future<Uint8List?> readClipboardPngImage() async {
  if (!Platform.isWindows) {
    return null;
  }

  final process = await Process.start(
    'powershell.exe',
    const <String>[
      '-NoLogo',
      '-NoProfile',
      '-NonInteractive',
      '-Sta',
      '-ExecutionPolicy',
      'Bypass',
      '-Command',
      _windowsClipboardScript,
    ],
  );

  final outputFuture = process.stdout.fold<List<int>>(
    <int>[],
    (buffer, chunk) => buffer..addAll(chunk),
  );
  final errorFuture = process.stderr.transform(utf8.decoder).join();

  final exitCode = await process.exitCode.timeout(
    const Duration(seconds: 8),
    onTimeout: () {
      process.kill();
      throw TimeoutException(
        'Чтение изображения из буфера заняло слишком много времени.',
      );
    },
  );
  final output = await outputFuture;
  final error = (await errorFuture).trim();

  if (exitCode != 0) {
    throw StateError(
      error.isEmpty
          ? 'Windows не смог прочитать изображение из буфера.'
          : error,
    );
  }
  if (output.isEmpty) {
    return null;
  }
  return Uint8List.fromList(output);
}
