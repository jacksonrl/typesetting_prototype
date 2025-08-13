import 'package:dart_eval/dart_eval_bridge.dart';
import 'package:dart_eval/stdlib/core.dart';
import 'package:typesetting_prototype/typesetting_prototype.dart';
import 'package:path/path.dart' as p;

import 'dart:typed_data';

part 'reconstructor_generated.dart';

late final String _scriptDirectory;
final Map<int, String> _typeIdToNameCache = {};

String getClassNameFromTypeId(Runtime runtime, int typeId) {
  if (_typeIdToNameCache.containsKey(typeId)) {
    return _typeIdToNameCache[typeId]!;
  }
  for (final libraryTypes in runtime.typeIds.values) {
    for (final entry in libraryTypes.entries) {
      if (entry.value == typeId) {
        final className = entry.key;
        _typeIdToNameCache[typeId] = className;
        return className;
      }
    }
  }
  throw Exception('Could not find class name for typeId $typeId');
}

Document reconstructDocument(Runtime runtime, $Instance scriptDoc, String scriptDirectory) {
  _scriptDirectory = scriptDirectory;

  final bodyInstance = scriptDoc.$getProperty(runtime, 'body') as $Instance;
  final nativeBody = _reconstructPageLayout(runtime, bodyInstance);

  final pageFormatInstance = scriptDoc.$getProperty(runtime, 'pageFormat') as $Instance;
  final width = (pageFormatInstance.$getProperty(runtime, 'width') as $num).$value.toDouble();
  final height = (pageFormatInstance.$getProperty(runtime, 'height') as $num).$value.toDouble();
  final nativeFormat = PageFormat(width, height);

  final pageMarginInstance = scriptDoc.$getProperty(runtime, 'pageMargin') as $Instance;
  final nativeMargin = _reconstructEdgeInsets(runtime, pageMarginInstance);

  final tocBuilderValue = scriptDoc.$getProperty(runtime, 'tocBuilder');

  PageLayout Function(DocumentMetadataRegistry)? nativeTocBuilder;
  if (tocBuilderValue != $null()) {
    final scriptBuilder = tocBuilderValue as EvalCallable;
    nativeTocBuilder = (DocumentMetadataRegistry registry) {
      final records = [];
      for (final entry in registry.records) {
        print(entry.value);
        final value = switch (entry.value) {
          FootnoteLayoutInfo() =>
            runtime.executeLib('package:typesetting_prototype/script_stdlib.dart', 'ScriptFootnoteItem.', [
                  entry.value.number,
                  $String(entry.value.content),
                ])
                as $Instance,
          String() => $String(entry.value),
          null => $null(),
          Object() => entry.value, //primitives
        };
        final record =
            runtime.executeLib('package:typesetting_prototype/script_stdlib.dart', 'ScriptMetadataRecord.', [
                    entry.key,
                    value,
                    entry.pageNumber,
                  ])
                  as $Instance
              ..$setProperty(runtime, "formattedPageNumber", $String(entry.formattedPageNumber));
        records.add(record);
      }
      print("1");
      final scriptRegistry =
          runtime.executeLib('package:typesetting_prototype/script_stdlib.dart', 'ScriptDocumentMetadataRegistry.')
              as $Instance;
      print("2");
      scriptRegistry.$setProperty(runtime, "records", $List.wrap(records));
      print("3");
      final scriptResult = scriptBuilder.call(runtime, null, [scriptRegistry]);
      print("4");
      return _reconstructPageLayout(runtime, scriptResult as $Instance);
    };
  }

  return Document(
    body: nativeBody,
    pageFormat: nativeFormat,
    pageMargin: nativeMargin,
    tocBuilder: nativeTocBuilder, //
  );
}

PageLayout _reconstructPageLayout(Runtime runtime, $Instance scriptLayout) {
  final headerValue = scriptLayout.$getProperty(runtime, 'header');
  final footerValue = scriptLayout.$getProperty(runtime, 'footer');
  final bodyList = (scriptLayout.$getProperty(runtime, 'body') as $List).$value;
  final footnoteBuilderValue = scriptLayout.$getProperty(runtime, 'footnoteBuilder');

  final PageSection? nativeHeader = headerValue == $null()
      ? null
      : _reconstructPageSection(runtime, headerValue as $Instance);

  final PageSection? nativeFooter = footerValue == $null()
      ? null
      : _reconstructPageSection(runtime, footerValue as $Instance);

  Widget Function(List<FootnoteItem>)? nativeFootnoteBuilder;
  if (footnoteBuilderValue != $null()) {
    final scriptBuilder = footnoteBuilderValue as EvalCallable;
    nativeFootnoteBuilder = (List<FootnoteItem> items) {
      final scriptItems = items
          .map(
            (item) =>
                runtime.executeLib('package:typesetting_prototype/script_stdlib.dart', 'ScriptFootnoteItem.', [
                      item.footnoteNumber,
                      $String(item.content),
                    ])
                    as $Instance,
          )
          .toList();
      final scriptList = $List.wrap(scriptItems);
      final scriptResult = scriptBuilder.call(runtime, null, [scriptList]) as $Instance;
      return _reconstructWidget(runtime, scriptResult);
    };
  }

  return PageLayout(
    header: nativeHeader,
    footer: nativeFooter,
    body: bodyList.map((child) => _reconstructWidget(runtime, child as $Instance)).toList(),
    footnoteBuilder: nativeFootnoteBuilder,
  );
}

PageSection _reconstructPageSection(Runtime runtime, $Instance scriptSection) {
  final heightValue = scriptSection.$getProperty(runtime, 'height');
  final prototypeValue = scriptSection.$getProperty(runtime, 'prototype');
  final builder = scriptSection.$getProperty(runtime, 'builder') as EvalCallable;

  Widget nativeBuilder(PageContext context) {
    final scriptContextInstance =
        runtime.executeLib('package:typesetting_prototype/script_stdlib.dart', 'ScriptPageContext.', [
              context.pageNumber,
              context.totalPages,
              $String(context.formattedPageNumber),
              $String(context.formattedTotalPages),
              context.sectionPageCount,
            ])
            as $Instance;
    final scriptResult = builder.call(runtime, null, [scriptContextInstance]) as $Instance;
    return _reconstructWidget(runtime, scriptResult);
  }

  if (heightValue != $null()) {
    final double height = (heightValue as $num).$value.toDouble();
    return PageSection.fixed(height: height, builder: nativeBuilder);
  } else {
    final Widget prototype = _reconstructWidget(runtime, prototypeValue as $Instance);
    return PageSection.prototyped(prototype: prototype, builder: nativeBuilder);
  }
}

Widget _reconstructWidget(Runtime runtime, $Instance instance) {
  final typeId = instance.$getRuntimeType(runtime);
  final className = getClassNameFromTypeId(runtime, typeId);

  final reconstructFunction = reconstructorMap[className];

  if (reconstructFunction != null) {
    return reconstructFunction(runtime, instance);
  }

  switch (className) {
    case 'ScriptResetPageNumber':
      final style = PageNumberStyle
          .values[(instance.$getProperty(runtime, 'style') as $Instance).$getProperty(runtime, 'index')!.$value];
      final startAt = (instance.$getProperty(runtime, 'startAt') as $int).$value;
      return ResetPageNumber(style: style, startAt: startAt);
  }

  throw 'Unknown script widget type: $className';
}

final Map<String, Font> _fontCache = {};

Font _reconstructFont(Runtime runtime, $Instance scriptFont) {
  final typeId = scriptFont.$getRuntimeType(runtime);
  final className = getClassNameFromTypeId(runtime, typeId);

  switch (className) {
    case 'ScriptBuiltInFont':
      final nameIndex = (scriptFont.$getProperty(runtime, 'name') as $Instance).$getProperty(runtime, 'index')!.$value;
      final name = BuiltInFontName.values[nameIndex];

      switch (name) {
        case BuiltInFontName.helvetica:
          return Font.helvetica;
        case BuiltInFontName.times:
          return Font.times;
        case BuiltInFontName.courier:
          return Font.courier;

        default:
          return Font.helvetica;
      }

    case 'TtfFont':
      final path = (scriptFont.$getProperty(runtime, 'filePath') as $String).$value;
      final absoluteFontPath = p.join(_scriptDirectory, path);

      if (_fontCache.containsKey(absoluteFontPath)) {
        return _fontCache[absoluteFontPath]!;
      }

      final font = TtfFont(absoluteFontPath);
      _fontCache[absoluteFontPath] = font;
      return font;

    default:
      print('⚠️ Unknown font type "$className". Falling back to Helvetica.');
      return Font.helvetica;
  }
}

MetadataMarker _reconstructMetadataMarker(Runtime runtime, $Instance scriptMetadataMarker) {
  final key = (scriptMetadataMarker.$getProperty(runtime, 'key') as $String).$value;
  final child = _reconstructWidget(runtime, scriptMetadataMarker.$getProperty(runtime, 'child') as $Instance);

  final valueInstance = scriptMetadataMarker.$getProperty(runtime, 'value') as $Value;
  dynamic finalValue;

  if (valueInstance is $Instance) {
    final valueTypeId = valueInstance.$getRuntimeType(runtime);
    final valueClassName = getClassNameFromTypeId(runtime, valueTypeId);

    if (valueClassName == 'ScriptFootnoteLayoutInfo') {
      final content = (valueInstance.$getProperty(runtime, 'content') as $String).$value;
      final position = (valueInstance.$getProperty(runtime, 'position') as $num).$value.toDouble();
      final number = (valueInstance.$getProperty(runtime, 'number') as $int).$value;

      finalValue = FootnoteLayoutInfo(content: content, position: position, number: number);
    } else {
      finalValue = valueInstance.$reified;
    }
  } else {
    finalValue = valueInstance.$reified;
  }

  return MetadataMarker(key: key, value: finalValue, child: child);
}

TableColumnWidth _reconstructTableColumnWidth(Runtime runtime, $Instance instance) {
  final typeId = instance.$getRuntimeType(runtime);
  final className = getClassNameFromTypeId(runtime, typeId);
  switch (className) {
    case 'ScriptFixedColumnWidth':
      final widthValue = instance.$getProperty(runtime, 'width');

      final width = (widthValue as $num).$value.toDouble();
      return FixedColumnWidth(width);

    case 'ScriptFlexColumnWidth':
      final flexValue = instance.$getProperty(runtime, 'flex');

      final flex = (flexValue as $num).$value.toDouble();
      return FlexColumnWidth(flex);

    case 'ScriptIntrinsicColumnWidth':
      final flexValue = instance.$getProperty(runtime, 'flex');

      final flex = flexValue == $null() ? 1.0 : (flexValue as $num).$value.toDouble();
      return IntrinsicColumnWidth(flex: flex);

    default:
      throw UnimplementedError('Cannot reconstruct unknown TableColumnWidth type: $className');
  }
}
