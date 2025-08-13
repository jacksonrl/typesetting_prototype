import 'dart:typed_data';

Future<void> savePdfPlatformSpecific(Uint8List bytes, String fileName) {
  throw UnsupportedError('PDF saving is not supported on this platform.');
}
