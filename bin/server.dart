import 'dart:io';

import 'package:lsp_server/lsp_server.dart';
import 'package:petitparser/petitparser.dart';
import 'package:typesetting_prototype/typesetting_prototype.dart';
import 'package:typesetting_prototype/script/script.dart';

void log(String message) {
  stderr.writeln("[Server] $message");
}

void main() async {
  log("Server Starting...");
  var connection = Connection(stdin, stdout);

  connection.onInitialize((params) async {
    return InitializeResult(
      capabilities: ServerCapabilities(
        textDocumentSync: const Either2.t1(TextDocumentSyncKind.Full),
      ),
    );
  });

  connection.onDidOpenTextDocument((params) async {
    _validateTextDocument(connection, params.textDocument.text, params.textDocument.uri);
  });

  connection.onDidChangeTextDocument((params) async {
    var fullText = params.contentChanges.map((e) {
      return e.map((c1) => c1.text, (c2) => c2.text);
    }).last;
    _validateTextDocument(connection, fullText, params.textDocument.uri);
  });

  await connection.listen();
}

void _validateTextDocument(Connection connection, String text, Uri documentUri) {
  final diagnostics = <Diagnostic>[];
  final engine = ScriptEngine();

  try {
    final error = engine.analyze(text);

    if (error != null) {
      int line = 0;
      int char = 0;
      int length = 5;
      String msg = error.toString();

      if (error is ScriptException) {
        msg = error.message;
        
        final lineCol = Token.lineAndColumnOf(text, error.offset);
        line = lineCol[0] - 1;
        char = lineCol[1] - 1;
        length = error.length;
        
        log("Error at $line:$char (len $length): $msg");
      } else {
        log("Generic Error: $msg");
      }

      diagnostics.add(Diagnostic(
        severity: DiagnosticSeverity.Error,
        source: 'Typesetting',
        message: msg,
        range: Range(
          start: Position(line: line, character: char),
          end: Position(line: line, character: char + length),
        ),
      ));
    } else {
      log("Analysis OK");
    }

  } catch (e, stack) {
    log("Crash: $e\n$stack");
  }

  connection.sendDiagnostics(
    PublishDiagnosticsParams(
      uri: documentUri,
      diagnostics: diagnostics,
    ),
  );
}