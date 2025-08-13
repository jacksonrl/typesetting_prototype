import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:web/web.dart' as web;
import 'dart:typed_data';
import 'package:http/http.dart' as http;

import 'package:typesetting_prototype/eval/reconstruct_document_js.dart';
import 'package:typesetting_prototype/typesetting_prototype.dart' as native;

@JS()
external JSObject defineDocument();

String? _currentPdfUrl;

void main() async {
  final generateButton = web.document.querySelector('#generate-pdf-button') as web.HTMLButtonElement;
  final outputContainer = web.document.querySelector('#output-container') as web.HTMLDivElement;

  final scriptEditor = web.document.querySelector('#script-editor') as web.HTMLTextAreaElement;

  try {
    final response = await http.get(Uri.parse('user_script.js'));
    if (response.statusCode == 200) {
      scriptEditor.value = response.body;
    } else {
      scriptEditor.value = '// Failed to load default script.';
    }
  } catch (e) {
    scriptEditor.value = '// Error loading default script:\n$e';
  }

  Future<void> generateAndDisplayPdf() async {
    generateButton.disabled = true;
    outputContainer.textContent = 'Executing script and generating PDF...';

    if (_currentPdfUrl != null) {
      web.URL.revokeObjectURL(_currentPdfUrl!);
    }

    try {
      final String userCode = scriptEditor.value;

      try {
        print("we are here");
        (web.window as JSObject).callMethod('eval'.toJS, userCode.toJS);
      } catch (e) {
        throw Exception(
          'JavaScript Syntax Error: The provided script could not be executed. Please check the console for details. Original error: $e',
        );
      }

      final JSObject scriptResult = defineDocument();
      final native.Document doc = reconstructDocumentFromJs(scriptResult);
      final Uint8List pdfBytes = await doc.save();

      final jsUint8Array = pdfBytes.toJS;
      final blobParts = [jsUint8Array].toJS;
      final blob = web.Blob(blobParts, web.BlobPropertyBag(type: 'application/pdf'));
      final url = web.URL.createObjectURL(blob);
      _currentPdfUrl = url;

      outputContainer.textContent = '';
      final iframe = web.document.createElement('iframe') as web.HTMLIFrameElement
        ..src = url
        ..width = '100%'
        ..height = '800px'
        ..style.border = '1px solid #ccc';
      outputContainer.append(iframe);
    } catch (e, st) {
      final errorMsg = '❌ An error occurred:\n$e\n\nStackTrace:\n$st';
      outputContainer.textContent = errorMsg;
      web.console.error(errorMsg.toJS);
    } finally {
      generateButton.disabled = false;
    }
  }

  generateButton.onclick = (web.MouseEvent event) {
    generateAndDisplayPdf();
  }.toJS;
}
