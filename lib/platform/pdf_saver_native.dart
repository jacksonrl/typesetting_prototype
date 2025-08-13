import 'dart:io';
import 'dart:typed_data';

/// Saves the PDF bytes to a file on the local filesystem.
Future<void> savePdfPlatformSpecific(Uint8List bytes, String fileName) async {
  final file = File(fileName);
  await file.writeAsBytes(bytes);
  print("Successfully saved PDF to $fileName");
}
