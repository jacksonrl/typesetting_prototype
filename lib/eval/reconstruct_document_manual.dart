import 'package:dart_eval/dart_eval_bridge.dart';
import 'package:dart_eval/stdlib/core.dart';
import 'package:typesetting_prototype/typesetting_prototype.dart';
import 'package:path/path.dart' as p;

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
  final nativeBody = reconstructPageLayout(runtime, bodyInstance);

  final pageFormatInstance = scriptDoc.$getProperty(runtime, 'pageFormat') as $Instance;

  final width = (pageFormatInstance.$getProperty(runtime, 'width') as $num).$value.toDouble();
  final height = (pageFormatInstance.$getProperty(runtime, 'height') as $num).$value.toDouble();
  final nativeFormat = PageFormat(width, height);

  final pageMarginInstance = scriptDoc.$getProperty(runtime, 'pageMargin') as $Instance;

  final nativeMargin = reconstructEdgeInsets(runtime, pageMarginInstance);

  return Document(body: nativeBody, pageFormat: nativeFormat, pageMargin: nativeMargin);
}

PageLayout reconstructPageLayout(Runtime runtime, $Instance scriptLayout) {
  final headerInstance = scriptLayout.$getProperty(runtime, 'header') as $Instance;
  final footerInstance = scriptLayout.$getProperty(runtime, 'footer') as $Instance;
  final bodyList = (scriptLayout.$getProperty(runtime, 'body') as $List).$value;
  final footnoteBuilder = scriptLayout.$getProperty(runtime, 'footnoteBuilder');
  Widget Function(List<FootnoteItem>)? nativeFootnoteBuilder;
  if (footnoteBuilder != $null()) {
    final footnoteBuilderValue = footnoteBuilder as EvalCallable;
    final scriptBuilder = footnoteBuilderValue;
    nativeFootnoteBuilder = (List<FootnoteItem> items) {
      final scriptItems = items.map((item) {
        final constructorArgs = <dynamic>[item.footnoteNumber, $String(item.content)];
        return runtime.executeLib(
              'package:typesetting_prototype/script_stdlib.dart',
              'ScriptFootnoteItem.',
              constructorArgs,
            )
            as $Instance;
      }).toList();

      final scriptList = $List.wrap(scriptItems);
      final scriptResult = scriptBuilder.call(runtime, null, [scriptList]) as $Instance;

      return reconstructWidget(runtime, scriptResult);
    };
  }
  return PageLayout(
    header: reconstructPageSection(runtime, headerInstance),
    footer: reconstructPageSection(runtime, footerInstance),
    body: bodyList.map((child) => reconstructWidget(runtime, child as $Instance)).toList(),
    footnoteBuilder: nativeFootnoteBuilder,
  );
}

PageSection reconstructPageSection(Runtime runtime, $Instance scriptSection) {
  final fixedHeight = (scriptSection.$getProperty(runtime, 'height') as $num).$value.toDouble();
  final builder = scriptSection.$getProperty(runtime, 'builder') as EvalCallable;

  Widget nativeBuilder(PageContext context) {
    final constructorArgs = <dynamic>[
      context.pageNumber,
      context.totalPages,
      $String(context.formattedPageNumber),
      $String(context.formattedTotalPages),
      context.sectionPageCount,
    ];
    final scriptContextInstance =
        runtime.executeLib('package:typesetting_prototype/script_stdlib.dart', 'ScriptPageContext.', constructorArgs)
            as $Instance;
    final scriptResult = builder.call(runtime, null, [scriptContextInstance]) as $Instance;
    return reconstructWidget(runtime, scriptResult);
  }

  return PageSection.fixed(height: fixedHeight, builder: nativeBuilder);
}

EdgeInsets reconstructEdgeInsets(Runtime runtime, $Instance instance) {
  final left = (instance.$getProperty(runtime, 'left') as $num).$value.toDouble();
  final top = (instance.$getProperty(runtime, 'top') as $num).$value.toDouble();
  final right = (instance.$getProperty(runtime, 'right') as $num).$value.toDouble();
  final bottom = (instance.$getProperty(runtime, 'bottom') as $num).$value.toDouble();
  return EdgeInsets.only(left: left, top: top, right: right, bottom: bottom);
}

CrossAxisAlignment reconstructCrossAxisAlignment(Runtime runtime, $Instance instance) {
  final index = (instance.$getProperty(runtime, 'index') as $int).$value;
  return CrossAxisAlignment.values[index];
}

MainAxisAlignment reconstructMainAxisAlignment(Runtime runtime, $Instance instance) {
  final index = (instance.$getProperty(runtime, 'index') as $int).$value;
  return MainAxisAlignment.values[index];
}

LineBreakMode reconstructLineBreakMode(Runtime runtime, $Instance instance) {
  final index = (instance.$getProperty(runtime, 'index') as $int).$value;
  return LineBreakMode.values[index];
}

BorderSide reconstructBorderSide(Runtime runtime, $Instance instance) {
  final width = (instance.$getProperty(runtime, 'width') as $num).$value.toDouble();
  return BorderSide(width: width);
}

Border reconstructBorder(Runtime runtime, $Instance instance) {
  final top = reconstructBorderSide(runtime, instance.$getProperty(runtime, 'top') as $Instance);
  final left = reconstructBorderSide(runtime, instance.$getProperty(runtime, 'left') as $Instance);
  final right = reconstructBorderSide(runtime, instance.$getProperty(runtime, 'right') as $Instance);
  final bottom = reconstructBorderSide(runtime, instance.$getProperty(runtime, 'bottom') as $Instance);
  return Border(top: top, left: left, right: right, bottom: bottom);
}

BoxDecoration reconstructBoxDecoration(Runtime runtime, $Instance instance) {
  final borderInst = instance.$getProperty(runtime, 'border');
  Border? border;
  if (borderInst != null && borderInst is $Instance) {
    border = reconstructBorder(runtime, borderInst);
  }
  return BoxDecoration(border: border);
}

PageNumberStyle reconstructPageNumberStyle(Runtime runtime, $Instance instance) {
  final index = (instance.$getProperty(runtime, 'index') as $int).$value;
  return PageNumberStyle.values[index];
}

List<Widget> reconstructChildren(Runtime runtime, $Instance instance) {
  final list = (instance as $List).$value;
  return list.map((child) => reconstructWidget(runtime, child as $Instance)).toList();
}

Widget reconstructWidget(Runtime runtime, $Instance instance) {
  final typeId = instance.$getRuntimeType(runtime);

  final className = getClassNameFromTypeId(runtime, typeId);

  switch (className) {
    case 'ScriptText':
      final text = (instance.$getProperty(runtime, 'text') as $String).$value;
      final fontSize = instance.$getProperty(runtime, 'fontSize');
      final lineHeight = (instance.$getProperty(runtime, 'lineHeight') as $num).$value.toDouble();
      final fontValue = instance.$getProperty(runtime, 'font');

      double? fontSizeValue = fontSize?.$value != null ? (fontSize as $num).$value.toDouble() : null;

      Font font;
      if (fontValue != null && fontValue is $Instance) {
        font = reconstructFont(runtime, fontValue);
      } else {
        font = Font.helvetica;
      }

      return Text(text, fontSize: fontSizeValue, font: font, lineHeight: lineHeight);

    case 'ScriptFlow':
      final children = instance.$getProperty(runtime, 'children') as $Instance;
      return Flow(children: reconstructChildren(runtime, children));

    case 'ScriptPadding':
      final padding = reconstructEdgeInsets(runtime, instance.$getProperty(runtime, 'padding') as $Instance);
      final child = reconstructWidget(runtime, instance.$getProperty(runtime, 'child') as $Instance);
      return Padding(padding: padding, child: child);

    case 'ScriptSizedBox':
      final widthValue = instance.$getProperty(runtime, 'width');
      final heightValue = instance.$getProperty(runtime, 'height');
      final childValue = instance.$getProperty(runtime, 'child');
      final double? width = (widthValue is $num) ? widthValue.$value.toDouble() : null;
      final double? height = (heightValue is $num) ? heightValue.$value.toDouble() : null;
      final Widget? child = (childValue is $Instance) ? reconstructWidget(runtime, childValue) : null;
      return SizedBox(width: width, height: height, child: child);

    case 'ScriptColumn':
      final children = instance.$getProperty(runtime, 'children') as $Instance;
      final crossAxisAlignment = reconstructCrossAxisAlignment(
        runtime,
        instance.$getProperty(runtime, 'crossAxisAlignment') as $Instance,
      );
      final mainAxisAlignment = reconstructMainAxisAlignment(
        runtime,
        instance.$getProperty(runtime, 'mainAxisAlignment') as $Instance,
      );
      return Column(
        children: reconstructChildren(runtime, children),
        crossAxisAlignment: crossAxisAlignment,
        mainAxisAlignment: mainAxisAlignment,
      );

    case 'ScriptFlowFill':
      final child = reconstructWidget(runtime, instance.$getProperty(runtime, 'child') as $Instance);
      return FlowFill(child: child);

    case 'ScriptKeepTogether':
      final first = reconstructWidget(runtime, instance.$getProperty(runtime, 'first') as $Instance);
      final second = reconstructWidget(runtime, instance.$getProperty(runtime, 'second') as $Instance);
      return KeepTogether(first: first, second: second);

    case 'ScriptRow':
      final children = instance.$getProperty(runtime, 'children') as $Instance;
      return Row(children: reconstructChildren(runtime, children));

    case 'ScriptExpanded':
      final child = reconstructWidget(runtime, instance.$getProperty(runtime, 'child') as $Instance);
      final flex = (instance.$getProperty(runtime, 'flex') as $int).$value;
      return Expanded(child: child, flex: flex);

    case 'ScriptRepeater':
      final text = (instance.$getProperty(runtime, 'text') as $String).$value;
      final fontSize = (instance.$getProperty(runtime, 'fontSize') as $num).$value.toDouble();
      return Repeater(text, fontSize: fontSize);

    case 'ScriptLineBreakConfiguration':
      final mode = reconstructLineBreakMode(runtime, instance.$getProperty(runtime, 'mode') as $Instance);
      final child = reconstructWidget(runtime, instance.$getProperty(runtime, 'child') as $Instance);
      return LineBreakConfiguration(mode: mode, child: child);

    case 'ScriptFormattedText':
      final text = (instance.$getProperty(runtime, 'text') as $String).$value;
      final fontSize = (instance.$getProperty(runtime, 'fontSize') as $num).$value.toDouble();
      final lineHeight = (instance.$getProperty(runtime, 'lineHeight') as $num).$value.toDouble();
      final newlinesForBreak = (instance.$getProperty(runtime, 'newlinesForBreak') as $int).$value;
      final indentFirst = (instance.$getProperty(runtime, 'indentFirstParagraph') as $bool).$value;
      final paragraphIndentValue = instance.$getProperty(runtime, 'paragraphIndent');
      final double? paragraphIndent = (paragraphIndentValue is $num) ? paragraphIndentValue.$value.toDouble() : null;
      final fontValue = instance.$getProperty(runtime, 'fontFamily');
      FontFamily? fontFamily;
      if (fontValue != null && fontValue is $Instance) {
        fontFamily = FontFamily.fromFont(reconstructFont(runtime, fontValue));
      }
      fontFamily = FontFamily.helvetica;
      return FormattedText(
        text,
        fontSize: fontSize,
        lineHeight: lineHeight,
        fontFamily: fontFamily,
        newlinesForBreak: newlinesForBreak,
        paragraphIndent: paragraphIndent,
        indentFirstParagraph: indentFirst,
      );

    case 'ScriptMetadataMarker':
      final key = (instance.$getProperty(runtime, 'key') as $String).$value;
      final child = reconstructWidget(runtime, instance.$getProperty(runtime, 'child') as $Instance);

      final valueInstance = instance.$getProperty(runtime, 'value') as $Value;
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

    case 'ScriptMultiColumn':
      final columnCount = (instance.$getProperty(runtime, 'columnCount') as $int).$value;
      final columnSpacing = (instance.$getProperty(runtime, 'columnSpacing') as $num).$value.toDouble();
      final children = instance.$getProperty(runtime, 'children') as $Instance;
      return MultiColumn(
        columnCount: columnCount,
        columnSpacing: columnSpacing,
        children: reconstructChildren(runtime, children),
      );

    case 'ScriptMultiColumnFlow':
      final columnCount = (instance.$getProperty(runtime, 'columnCount') as $int).$value;
      final columnSpacing = (instance.$getProperty(runtime, 'columnSpacing') as $num).$value.toDouble();
      final children = instance.$getProperty(runtime, 'children') as $Instance;
      return MultiColumnFlow(
        columnCount: columnCount,
        columnSpacing: columnSpacing,
        children: reconstructChildren(runtime, children),
      );

    case 'ScriptSyncedColumns':
      final topChildren = instance.$getProperty(runtime, 'topChildren') as $Instance;
      final topColumnCount = (instance.$getProperty(runtime, 'topColumnCount') as $int).$value;
      final topColumnSpacing = (instance.$getProperty(runtime, 'topColumnSpacing') as $num).$value.toDouble();
      final bottomChildren = instance.$getProperty(runtime, 'bottomChildren') as $Instance;
      final bottomColumnCount = (instance.$getProperty(runtime, 'bottomColumnCount') as $int).$value;
      final bottomColumnSpacing = (instance.$getProperty(runtime, 'bottomColumnSpacing') as $num).$value.toDouble();
      final spacing = (instance.$getProperty(runtime, 'spacing') as $num).$value.toDouble();
      return SyncedColumns(
        topChildren: reconstructChildren(runtime, topChildren),
        topColumnCount: topColumnCount,
        topColumnSpacing: topColumnSpacing,
        bottomChildren: reconstructChildren(runtime, bottomChildren),
        bottomColumnCount: bottomColumnCount,
        bottomColumnSpacing: bottomColumnSpacing,
        spacing: spacing,
      );

    case 'ScriptDecoratedBox':
      final decoration = reconstructBoxDecoration(runtime, instance.$getProperty(runtime, 'decoration') as $Instance);
      final child = reconstructWidget(runtime, instance.$getProperty(runtime, 'child') as $Instance);
      return DecoratedBox(decoration: decoration, child: child);

    case 'ScriptUnderline':
      final child = reconstructWidget(runtime, instance.$getProperty(runtime, 'child') as $Instance);
      final thickness = (instance.$getProperty(runtime, 'thickness') as $num).$value.toDouble();
      return Underline(child: child, thickness: thickness);

    case 'ScriptResetPageNumber':
      final style = reconstructPageNumberStyle(runtime, instance.$getProperty(runtime, 'style') as $Instance);
      final startAt = (instance.$getProperty(runtime, 'startAt') as $int).$value;
      return ResetPageNumber(style: style, startAt: startAt);

    default:
      throw 'Unknown script widget type: $className';
  }
}

final Map<String, Font> _fontCache = {};

Font reconstructFont(Runtime runtime, $Instance scriptFont) {
  final typeId = scriptFont.$getRuntimeType(runtime);
  final className = getClassNameFromTypeId(runtime, typeId);

  switch (className) {
    case 'BuiltInFont':
      final name = (scriptFont.$getProperty(runtime, 'name') as $String).$value;
      return {'helvetica': Font.helvetica, 'times': Font.times, 'courier': Font.courier}[name] ?? Font.helvetica;

    case 'TtfFont':
      final fileInstance = scriptFont.$getProperty(runtime, 'path') as $Instance;

      final path = fileInstance.$value as String;

      final absoluteFontPath = p.join(_scriptDirectory, path);

      final filePath = absoluteFontPath;

      print('Loading font from resolved absolute path: $filePath');

      if (_fontCache.containsKey(filePath)) {
        return _fontCache[filePath]!;
      }

      final font = TtfFont(filePath);

      _fontCache[filePath] = font;
      return font;

    default:
      print('⚠️ Unknown font type "$className". Falling back to Helvetica.');
      return Font.helvetica;
  }
}
