import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:web/web.dart' as web;
import 'dart:typed_data';
import 'package:http/http.dart' as http;

import 'package:typesetting_prototype/eval/reconstruct_document_js.dart';
import 'package:typesetting_prototype/typesetting_prototype.dart' as native;

@JS()
external JSPromise<JSString> getEditorContent();

@JS()
external JSObject defineDocument();

@JS()
external void displayPdf(String url);

@JS()
external void displayPdfError(String message);

String? _currentPdfUrl;

@JSExport()
class MyDartApp {
  void startDartApp() {
    print("Dart app initialized. Generating initial PDF.");
    generateAndSendPdf();
  }

  @JSExport('generateAndSendPdf')
  Future<void> generateAndSendPdf() async {
    if (_currentPdfUrl != null) {
      web.URL.revokeObjectURL(_currentPdfUrl!);
      _currentPdfUrl = null;
    }

    try {
      final String userCode = (await getEditorContent().toDart).toDart;

      final libResponse = await http.get(Uri.parse('lib.js'));
      if (libResponse.statusCode != 200) {
        throw Exception('Could not load script library for execution.');
      }
      final String libraryCode = libResponse.body;
      final String fullCode = '$libraryCode\n\n$userCode';

      try {
        (web.window as JSObject).callMethod('eval'.toJS, fullCode.toJS);
      } catch (e) {
        throw Exception('JavaScript Syntax Error: $e');
      }

      final JSObject scriptResult = defineDocument();
      final native.Document doc = reconstructDocumentFromJs(scriptResult);
      final Uint8List pdfBytes = await doc.save();

      final jsUint8Array = pdfBytes.toJS;
      final blobParts = [jsUint8Array].toJS;
      final blob = web.Blob(blobParts, web.BlobPropertyBag(type: 'application/pdf'));

      _currentPdfUrl = web.URL.createObjectURL(blob);

      displayPdf(_currentPdfUrl!);
    } catch (e, st) {
      final errorMsg = '$e\n\nStackTrace:\n$st';
      web.console.error(errorMsg.toJS);
      displayPdfError(errorMsg);
    }
  }
}

void main() {
  final myApp = MyDartApp();
  final jsObject = createJSInteropWrapper(myApp);
  final window = globalContext;

  if (window.hasProperty('onDartReady'.toJS).toDart) {
    final onDartReady = window.getProperty('onDartReady'.toJS);
    if (onDartReady.isA<JSFunction>()) {
      (onDartReady as JSFunction).callAsFunction(null, jsObject);
    }
  }
}
