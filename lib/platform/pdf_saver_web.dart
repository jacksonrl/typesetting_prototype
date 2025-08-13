import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart';

Future<void> savePdfPlatformSpecific(Uint8List bytes, String fileName) async {
  final blobParts = [bytes.toJSBox].toJS;
  final blob = Blob(blobParts, BlobPropertyBag(type: 'application/pdf'));

  final url = URL.createObjectURL(blob);

  final anchor = document.createElement('a') as HTMLAnchorElement
    ..href = url
    ..download = fileName
    ..style.display = 'none';

  document.body!.append(anchor);
  anchor.click();
  anchor.remove();

  URL.revokeObjectURL(url);

  print("Triggered browser download for $fileName");
}
