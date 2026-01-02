import 'dart:io';
import 'package:typesetting_prototype/typesetting_prototype.dart';

void main() async {
  final scriptFile = File('bin/script.txt');
  if (!await scriptFile.exists()) {
    print("Error: script.txt not found.");
    return;
  }

  final scriptText = await scriptFile.readAsString();
  print("Processing script...");

  final engine = ScriptEngine();
  
  try {
    final result = engine.parseAndBuildDocument(scriptText, {});
    
    String fileName = 'output.pdf';
    
    final pageConfig = result.context.getVariable('__config_page');
    if (pageConfig != null && pageConfig.rawValue is Map) {
      final configMap = pageConfig.rawValue as Map;
      if (configMap.containsKey('name')) {
        fileName = '${configMap['name']}.pdf';
      }
    }

    final outputDir = Directory('output');
    if (!await outputDir.exists()) {
      await outputDir.create();
    }

    final outputPath = '${outputDir.path}/$fileName';

    print("Generating $outputPath...");
    await PdfGenerator.generatePdf(result.document, outputPath);
    print("Done.");

  } catch (e) {
    print("Error: $e");
  }
}