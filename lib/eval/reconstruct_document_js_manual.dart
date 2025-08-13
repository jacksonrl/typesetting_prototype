import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:typesetting_prototype/typesetting_prototype.dart';

@JS('Object.keys')
external JSArray _jsObjectKeys(JSObject obj);

dynamic _convertJSAnyToDart(JSAny? jsValue) {
  if (jsValue == null) return null;
  if (jsValue.isA<JSBoolean>()) return (jsValue as JSBoolean).toDart;
  if (jsValue.isA<JSString>()) return (jsValue as JSString).toDart;
  if (jsValue.isA<JSNumber>()) return (jsValue as JSNumber).toDartDouble;
  if (jsValue.isA<JSArray>()) return (jsValue as JSArray).toDart.map(_convertJSAnyToDart).toList();
  if (jsValue.isA<JSObject>()) {
    jsValue as JSObject;
    if (getProperty<JSBoolean>(jsValue, '_isFootnoteLayoutInfo')?.toDart ?? false) {
      final content = (getProperty<JSString>(jsValue, 'content')!).toDart;
      return FootnoteLayoutInfo(content: content, position: 0.0, number: 0);
    }
    final map = <String, dynamic>{};
    final keys = _jsObjectKeys(jsValue);
    for (final key in keys.toDart) {
      final keyString = (key as JSString).toDart;
      map[keyString] = _convertJSAnyToDart(jsValue.getProperty(keyString.toJS));
    }
    return map;
  }
  return null;
}

T? getProperty<T extends JSAny>(JSObject obj, String key) {
  if (obj.hasProperty(key.toJS).toDart) {
    final value = obj.getProperty(key.toJS);
    if (value != null) {
      return value as T;
    }
  }
  return null;
}

Document reconstructDocumentFromJs(JSObject scriptDoc) {
  final bodyInstance = getProperty<JSObject>(scriptDoc, 'body')!;
  final nativeBody = reconstructPageLayout(bodyInstance);
  final pageMarginInstance = getProperty<JSObject>(scriptDoc, 'pageMargin');
  if (!pageMarginInstance.isUndefinedOrNull) {
    final nativeMargin = reconstructEdgeInsets(pageMarginInstance!);
    return Document(body: nativeBody, pageMargin: nativeMargin);
  }
  return Document(body: nativeBody);
}

PageLayout reconstructPageLayout(JSObject scriptLayout) {
  final headerInstance = getProperty<JSObject>(scriptLayout, 'header');
  final footerInstance = getProperty<JSObject>(scriptLayout, 'footer');
  final bodyArray = getProperty<JSArray>(scriptLayout, 'body')!;
  final footnoteBuilderFunc = getProperty<JSFunction>(scriptLayout, 'footnoteBuilder');

  final nativeHeader = headerInstance != null ? reconstructPageSection(headerInstance) : null;
  final nativeFooter = footerInstance != null ? reconstructPageSection(footerInstance) : null;

  Widget Function(List<FootnoteItem>)? nativeFootnoteBuilder;

  if (footnoteBuilderFunc != null) {
    nativeFootnoteBuilder = (List<FootnoteItem> items) {
      final jsItems = items
          .map((item) {
            final jsItem = JSObject();
            jsItem.setProperty('footnoteNumber'.toJS, item.footnoteNumber.toJS);
            jsItem.setProperty('content'.toJS, item.content.toJS);
            return jsItem;
          })
          .toList()
          .toJS;
      final scriptResult = footnoteBuilderFunc.callAsFunction(null, jsItems) as JSObject;
      return reconstructWidget(scriptResult);
    };
  }

  return PageLayout(
    header: nativeHeader,
    footer: nativeFooter,
    body: bodyArray.toDart.map((child) => reconstructWidget(child as JSObject)).toList(),
    footnoteBuilder: nativeFootnoteBuilder,
  );
}

JSAny? _convertDartValueToJs(dynamic value) {
  if (value is String) return value.toJS;
  if (value is num) return value.toJS;
  if (value is bool) return value.toJS;

  return null;
}

PageSection reconstructPageSection(JSObject scriptSection) {
  final fixedHeight = (getProperty<JSNumber>(scriptSection, 'height')!).toDartDouble;
  print(fixedHeight);
  final builder = getProperty<JSFunction>(scriptSection, 'builder')!;
  Widget nativeBuilder(PageContext context) {
    final jsContext = JSObject();
    jsContext.setProperty('pageNumber'.toJS, context.pageNumber.toJS);
    jsContext.setProperty('totalPages'.toJS, context.totalPages.toJS);
    jsContext.setProperty('formattedPageNumber'.toJS, context.formattedPageNumber.toJS);

    final jsMetadata = context.metadata
        .map((record) {
          final jsRecord = JSObject();
          jsRecord.setProperty('key'.toJS, record.key.toJS);

          jsRecord.setProperty('value'.toJS, _convertDartValueToJs(record.value));
          jsRecord.setProperty('pageNumber'.toJS, record.pageNumber?.toJS);
          jsRecord.setProperty('formattedPageNumber'.toJS, record.formattedPageNumber.toJS);
          return jsRecord;
        })
        .toList()
        .toJS;
    jsContext.setProperty('metadata'.toJS, jsMetadata);

    final scriptResult = builder.callAsFunction(null, jsContext) as JSObject;
    return reconstructWidget(scriptResult);
  }

  return PageSection.fixed(height: fixedHeight, builder: nativeBuilder);
}

List<Widget> reconstructChildren(JSObject instance, String key) {
  final childrenArray = getProperty<JSArray>(instance, key);
  if (childrenArray == null) return [];
  return childrenArray.toDart.map((child) => reconstructWidget(child as JSObject)).toList();
}

CrossAxisAlignment reconstructCrossAxisAlignment(JSObject instance, String key) {
  final value = getProperty<JSString>(instance, key)?.toDart;
  return switch (value) {
    'end' => CrossAxisAlignment.end,
    'center' => CrossAxisAlignment.center,
    'stretch' => CrossAxisAlignment.stretch,
    _ => CrossAxisAlignment.start,
  };
}

MainAxisAlignment reconstructMainAxisAlignment(JSObject instance, String key) {
  final value = getProperty<JSString>(instance, key)?.toDart;
  return switch (value) {
    'end' => MainAxisAlignment.end,
    'center' => MainAxisAlignment.center,
    _ => MainAxisAlignment.start,
  };
}

PageNumberStyle reconstructPageNumberStyle(JSObject instance, String key) {
  final value = getProperty<JSString>(instance, key)?.toDart;
  return switch (value) {
    'romanLower' => PageNumberStyle.romanLower,
    'romanUpper' => PageNumberStyle.romanUpper,
    _ => PageNumberStyle.arabic,
  };
}

BorderSide reconstructBorderSide(JSObject instance) {
  final width = (getProperty<JSNumber>(instance, 'width')!).toDartDouble;
  return BorderSide(width: width);
}

Border reconstructBorder(JSObject instance) {
  final topJS = getProperty<JSObject>(instance, 'top');
  final leftJS = getProperty<JSObject>(instance, 'left');
  final rightJS = getProperty<JSObject>(instance, 'right');
  final bottomJS = getProperty<JSObject>(instance, 'bottom');
  final top = topJS != null ? reconstructBorderSide(topJS) : BorderSide.none;
  final left = leftJS != null ? reconstructBorderSide(leftJS) : BorderSide.none;
  final right = rightJS != null ? reconstructBorderSide(rightJS) : BorderSide.none;
  final bottom = bottomJS != null ? reconstructBorderSide(bottomJS) : BorderSide.none;
  return Border(top: top, left: left, right: right, bottom: bottom);
}

BoxDecoration reconstructBoxDecoration(JSObject instance) {
  final borderInst = getProperty<JSObject>(instance, 'border');
  Border? border;
  if (borderInst != null) {
    border = reconstructBorder(borderInst);
  }
  return BoxDecoration(border: border);
}

EdgeInsets reconstructEdgeInsets(JSObject instance) {
  final left = getProperty<JSNumber>(instance, 'left');
  final top = getProperty<JSNumber>(instance, 'top');
  final right = getProperty<JSNumber>(instance, 'right');
  final bottom = getProperty<JSNumber>(instance, 'bottom');
  return EdgeInsets.only(
    left: left?.toDartDouble ?? 0,
    top: top?.toDartDouble ?? 0,
    right: right?.toDartDouble ?? 0,
    bottom: bottom?.toDartDouble ?? 0,
  );
}

LineBreakMode reconstructLineBreakMode(JSObject instance, String key) {
  final value = getProperty<JSString>(instance, key)?.toDart;
  return switch (value) {
    'knuthPlass' => LineBreakMode.knuthPlass,
    _ => LineBreakMode.greedy,
  };
}

Alignment reconstructAlignment(JSObject instance, String key) {
  final alignObj = getProperty<JSObject>(instance, key);
  if (alignObj == null) return Alignment.center;
  final x = (getProperty<JSNumber>(alignObj, 'x')!).toDartDouble;
  final y = (getProperty<JSNumber>(alignObj, 'y')!).toDartDouble;
  return Alignment(x, y);
}

TableCellVerticalAlignment reconstructTableCellVerticalAlignment(JSObject instance, String key) {
  final value = getProperty<JSString>(instance, key)?.toDart;
  return switch (value) {
    'middle' => TableCellVerticalAlignment.middle,
    'bottom' => TableCellVerticalAlignment.bottom,
    'fill' => TableCellVerticalAlignment.fill,
    _ => TableCellVerticalAlignment.top,
  };
}

Map<int, TableColumnWidth> reconstructTableColumnWidths(JSObject instance, String key) {
  final jsWidths = getProperty<JSObject>(instance, key);
  if (jsWidths == null) return {};

  final Map<int, TableColumnWidth> dartWidths = {};
  final keys = _jsObjectKeys(jsWidths);

  for (final jsKey in keys.toDart) {
    final keyString = (jsKey as JSString).toDart;
    final intKey = int.tryParse(keyString);
    if (intKey == null) continue;

    final jsWidthValue = jsWidths.getProperty(keyString.toJS) as JSObject;
    final type = (getProperty<JSString>(jsWidthValue, '_type')!).toDart;

    switch (type) {
      case 'FixedColumnWidth':
        final width = (getProperty<JSNumber>(jsWidthValue, 'width')!).toDartDouble;
        dartWidths[intKey] = FixedColumnWidth(width);
        break;
      case 'FlexColumnWidth':
        final flex = (getProperty<JSNumber>(jsWidthValue, 'flex')!).toDartDouble;
        dartWidths[intKey] = FlexColumnWidth(flex);
        break;
      case 'IntrinsicColumnWidth':
        final flex = getProperty<JSNumber>(jsWidthValue, 'flex')?.toDartDouble ?? 1.0;
        dartWidths[intKey] = IntrinsicColumnWidth(flex: flex);
        break;
    }
  }
  return dartWidths;
}

List<TableCell> reconstructTableCells(JSArray jsCells) {
  return jsCells.toDart.map((jsCellObj) {
    final jsCell = jsCellObj as JSObject;
    return TableCell(
      child: reconstructWidget(getProperty<JSObject>(jsCell, 'child')!),
      rowSpan: (getProperty<JSNumber>(jsCell, 'rowSpan')!).toDartInt,
      colSpan: (getProperty<JSNumber>(jsCell, 'colSpan')!).toDartInt,
      verticalAlignment: reconstructTableCellVerticalAlignment(jsCell, 'verticalAlignment'),
    );
  }).toList();
}

List<TableRow> reconstructTableRows(JSObject instance, String key) {
  final jsRows = getProperty<JSArray>(instance, key);
  if (jsRows == null) return [];
  return jsRows.toDart.map((jsRowObj) {
    final jsRow = jsRowObj as JSObject;
    return TableRow(children: reconstructTableCells(getProperty<JSArray>(jsRow, 'children')!));
  }).toList();
}

Widget reconstructWidget(JSObject instance) {
  final type = (getProperty<JSString>(instance, '_type')!).toDart;
  switch (type) {
    case 'ScriptText':
      final text = (getProperty<JSString>(instance, 'text')!).toDart;
      final fontSize = getProperty<JSNumber>(instance, 'fontSize');
      if (fontSize != null) {
        return Text(text, fontSize: fontSize.toDartDouble);
      }
      return Text(text);
    case 'ScriptPadding':
      final padding = reconstructEdgeInsets(getProperty<JSObject>(instance, 'padding')!);
      final child = reconstructWidget(getProperty<JSObject>(instance, 'child')!);
      return Padding(padding: padding, child: child);
    case 'ScriptSizedBox':
      final width = getProperty<JSNumber>(instance, 'width')?.toDartDouble;
      final height = getProperty<JSNumber>(instance, 'height')?.toDartDouble;
      final childObj = getProperty<JSObject>(instance, 'child');
      final child = childObj != null ? reconstructWidget(childObj) : null;
      return SizedBox(width: width, height: height, child: child);
    case 'ScriptColumn':
      return Column(
        children: reconstructChildren(instance, 'children'),
        crossAxisAlignment: reconstructCrossAxisAlignment(instance, 'crossAxisAlignment'),
        mainAxisAlignment: reconstructMainAxisAlignment(instance, 'mainAxisAlignment'),
      );
    case 'ScriptRow':
      return Row(children: reconstructChildren(instance, 'children'));
    case 'ScriptExpanded':
      final child = reconstructWidget(getProperty<JSObject>(instance, 'child')!);
      final flex = (getProperty<JSNumber>(instance, 'flex')!).toDartInt;
      return Expanded(child: child, flex: flex);
    case 'ScriptFlow':
      return Flow(children: reconstructChildren(instance, 'children'));
    case 'ScriptFormattedText':
      return FormattedText(
        (getProperty<JSString>(instance, 'text')!).toDart,
        fontSize: (getProperty<JSNumber>(instance, 'fontSize')!).toDartDouble,
        lineHeight: (getProperty<JSNumber>(instance, 'lineHeight')!).toDartDouble,
        fontFamily: FontFamily.helvetica,
        newlinesForBreak: (getProperty<JSNumber>(instance, 'newlinesForBreak')!).toDartInt,
        paragraphIndent: getProperty<JSNumber>(instance, 'paragraphIndent')?.toDartDouble,
        indentFirstParagraph: (getProperty<JSBoolean>(instance, 'indentFirstParagraph')!).toDart,
      );
    case 'ScriptMultiColumn':
      return MultiColumn(
        columnCount: (getProperty<JSNumber>(instance, 'columnCount')!).toDartInt,
        columnSpacing: (getProperty<JSNumber>(instance, 'columnSpacing')!).toDartDouble,
        children: reconstructChildren(instance, 'children'),
      );
    case 'ScriptResetPageNumber':
      return ResetPageNumber(
        style: reconstructPageNumberStyle(instance, 'style'),
        startAt: (getProperty<JSNumber>(instance, 'startAt')!).toDartInt,
      );
    case 'ScriptUnderline':
      return Underline(
        child: reconstructWidget(getProperty<JSObject>(instance, 'child')!),
        thickness: (getProperty<JSNumber>(instance, 'thickness')!).toDartDouble,
      );
    case 'ScriptFlowFill':
      return FlowFill(child: reconstructWidget(getProperty<JSObject>(instance, 'child')!));
    case 'ScriptKeepTogether':
      return KeepTogether(
        first: reconstructWidget(getProperty<JSObject>(instance, 'first')!),
        second: reconstructWidget(getProperty<JSObject>(instance, 'second')!),
      );
    case 'ScriptRepeater':
      return Repeater(
        (getProperty<JSString>(instance, 'text')!).toDart,
        fontSize: (getProperty<JSNumber>(instance, 'fontSize')!).toDartDouble,
      );
    case 'ScriptMetadataMarker':
      return MetadataMarker(
        key: (getProperty<JSString>(instance, 'key')!).toDart,
        value: _convertJSAnyToDart(getProperty<JSAny>(instance, 'value')!),
        child: reconstructWidget(getProperty<JSObject>(instance, 'child')!),
      );
    case 'ScriptMultiColumnFlow':
      return MultiColumnFlow(
        columnCount: (getProperty<JSNumber>(instance, 'columnCount')!).toDartInt,
        columnSpacing: (getProperty<JSNumber>(instance, 'columnSpacing')!).toDartDouble,
        children: reconstructChildren(instance, 'children'),
      );
    case 'ScriptSyncedColumns':
      return SyncedColumns(
        topChildren: reconstructChildren(instance, 'topChildren'),
        topColumnCount: (getProperty<JSNumber>(instance, 'topColumnCount')!).toDartInt,
        topColumnSpacing: (getProperty<JSNumber>(instance, 'topColumnSpacing')!).toDartDouble,
        bottomChildren: reconstructChildren(instance, 'bottomChildren'),
        bottomColumnCount: (getProperty<JSNumber>(instance, 'bottomColumnCount')!).toDartInt,
        bottomColumnSpacing: (getProperty<JSNumber>(instance, 'bottomColumnSpacing')!).toDartDouble,
        spacing: (getProperty<JSNumber>(instance, 'spacing')!).toDartDouble,
      );
    case 'ScriptDecoratedBox':
      return DecoratedBox(
        decoration: reconstructBoxDecoration(getProperty<JSObject>(instance, 'decoration')!),
        child: reconstructWidget(getProperty<JSObject>(instance, 'child')!),
      );
    case 'ScriptAlign':
      return Align(
        alignment: reconstructAlignment(instance, 'alignment'),
        child: reconstructWidget(getProperty<JSObject>(instance, 'child')!),
      );
    case 'ScriptLineBreakConfiguration':
      return LineBreakConfiguration(
        mode: reconstructLineBreakMode(instance, 'mode'),
        child: reconstructWidget(getProperty<JSObject>(instance, 'child')!),
      );
    case 'ScriptTable':
      return Table(
        children: reconstructTableRows(instance, 'children'),
        columnWidths: reconstructTableColumnWidths(instance, 'columnWidths'),
        defaultVerticalAlignment: reconstructTableCellVerticalAlignment(instance, 'defaultVerticalAlignment'),
      );
    default:
      throw 'Unknown script widget type: $type';
  }
}
