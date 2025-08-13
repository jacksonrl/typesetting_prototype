import 'dart:typed_data';
import 'package:dart_eval/dart_eval.dart';
import 'package:dart_eval/dart_eval_bridge.dart';
import 'package:http/http.dart' as http;
import 'package:typesetting_prototype/eval/reconstruct_document.dart';

Future<Uint8List> runScriptOnWeb(String scriptContent) async {
  final stdlibUri = Uri.parse('packages/typesetting_prototype/eval/script_stdlib.dart');
  final stdlibResponse = await http.get(stdlibUri);
  if (stdlibResponse.statusCode != 200) {
    throw Exception('Failed to load script_stdlib.dart');
  }
  final stdlibContent = stdlibResponse.body;

  final compiler = Compiler();
  compiler.entrypoints.add('package:typesetting_prototype/script_stdlib.dart');
  final program = compiler.compile({
    'typesetting_prototype': {'main.dart': scriptContent, 'script_stdlib.dart': stdlibContent},
  });

  final runtime = Runtime.ofProgram(program);

  print('Executing script...');
  final result = runtime.executeLib('package:typesetting_prototype/main.dart', 'main') as $Instance;

  print('Reconstructing document...');
  final document = reconstructDocument(runtime, result, '');

  print('Generating PDF...');
  return await document.save();
}
