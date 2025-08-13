import 'dart:io';
import 'package:dart_eval/dart_eval.dart';
import 'package:dart_eval/dart_eval_bridge.dart';
import 'package:dart_eval/dart_eval_security.dart';
import 'package:typesetting_prototype/eval/reconstruct_document.dart';
import 'package:path/path.dart' as p;
import 'package:typesetting_prototype/typesetting_prototype.dart';

void main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: dart run lib/eval/eval_runner.dart <path_to_script.dart>');
    exit(1);
  }
  final scriptPath = args.single;

  final absoluteScriptPath = p.absolute(scriptPath);
  final scriptDirectory = p.dirname(absoluteScriptPath);
  print('Script directory set to: $scriptDirectory');

  final scriptContent = await File(scriptPath).readAsString();

  final stdlibPath = p.join(p.dirname(Platform.script.toFilePath()), 'script_stdlib.dart');
  final stdlibContent = await File(stdlibPath).readAsString();

  final compiler = Compiler();
  compiler.entrypoints.add('package:typesetting_prototype/script_stdlib.dart');

  final program = compiler.compile({
    'typesetting_prototype': {'main.dart': scriptContent, 'script_stdlib.dart': stdlibContent},
  });

  final runtime = Runtime.ofProgram(program);
  runtime.grant(FilesystemReadPermission.any);

  print('Executing script...');

  final result = runtime.executeLib('package:typesetting_prototype/main.dart', 'main') as $Instance;

  final document = reconstructDocument(runtime, result, scriptDirectory);

  print('Generating PDF...');
  PdfGenerator.generatePdf(document, "final_test.pdf");

  print('Successfully generated final_test.pdf from script: $scriptPath');
}
