import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';
import 'package:typesetting_prototype/typesetting_prototype.dart';

part 'js_reconstructor_generated.dart';

@JS('Object.keys')
external JSArray _jsObjectKeys(JSObject obj);

T? getProperty<T extends JSAny>(JSObject obj, String key) {
  if (obj.hasProperty(key.toJS).toDart) {
    final value = obj.getProperty(key.toJS);
    if (value != null && !value.isUndefinedOrNull) {
      return value as T;
    }
  }
  return null;
}

Document reconstructDocumentFromJs(JSObject scriptDoc) {
  final bodyInstance = getProperty<JSObject>(scriptDoc, 'body')!;
  final nativeBody = reconstructPageLayout(bodyInstance);

  final pageFormatInstance = getProperty<JSObject>(scriptDoc, 'pageFormat')!;
  final width = (getProperty<JSNumber>(pageFormatInstance, 'width')!).toDartDouble;
  final height = (getProperty<JSNumber>(pageFormatInstance, 'height')!).toDartDouble;
  final nativeFormat = PageFormat(width, height);

  final pageMarginInstance = getProperty<JSObject>(scriptDoc, 'pageMargin')!;
  final nativeMargin = _reconstructEdgeInsets(pageMarginInstance);

  final tocBuilderFunc = getProperty<JSFunction>(scriptDoc, 'tocBuilder');

  PageLayout Function(DocumentMetadataRegistry)? nativeTocBuilder;
  if (tocBuilderFunc != null) {
    nativeTocBuilder = (DocumentMetadataRegistry registry) {
      final jsRegistry = JSObject();
      final jsRecords = registry.records
          .map((entry) {
            final jsRecord = JSObject();
            jsRecord.setProperty('value'.toJS, _convertDartValueToJs(entry.value));
            jsRecord.setProperty('key'.toJS, entry.key.toJS);
            jsRecord.setProperty('pageNumber'.toJS, entry.pageNumber!.toJS);
            jsRecord.setProperty('formattedPageNumber'.toJS, entry.formattedPageNumber.toJS);
            return jsRecord;
          })
          .toList()
          .toJS;

      jsRegistry.setProperty('records'.toJS, jsRecords);
      final scriptResult = tocBuilderFunc.callAsFunction(null, jsRegistry) as JSObject;
      return reconstructPageLayout(scriptResult);
    };
  }
  return Document(body: nativeBody, pageFormat: nativeFormat, pageMargin: nativeMargin, tocBuilder: nativeTocBuilder);
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

Image reconstructImage(JSObject instance) {
  final bytesJS = getProperty<JSArray>(instance, 'bytes')!;
  final bytes = Uint8List.fromList(bytesJS.toDart.map((e) => (e as JSNumber).toDartInt).toList());
  final width = getProperty<JSNumber>(instance, 'width')?.toDartDouble;
  final height = getProperty<JSNumber>(instance, 'height')?.toDartDouble;
  return Image.memory(bytes, width: width, height: height);
}

MetadataMarker reconstructMetadataMarker(JSObject instance) {
  return MetadataMarker(
    key: (getProperty<JSString>(instance, 'key')!).toDart,
    value: _convertJSAnyToDart(getProperty<JSAny>(instance, 'value')!),
    child: reconstructWidget(getProperty<JSObject>(instance, 'child')!),
  );
}

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

Font reconstructFont(JSObject instance) {
  return Font.helvetica;
}

JSAny? _convertDartValueToJs(dynamic value) {
  if (value is String) return value.toJS;
  if (value is num) return value.toJS;
  if (value is bool) return value.toJS;
  if (value is FootnoteLayoutInfo) {
    final jsFootnote = JSObject();
    jsFootnote.setProperty('_type'.toJS, 'FootnoteLayoutInfo'.toJS);
    jsFootnote.setProperty('content'.toJS, value.content.toJS);
    jsFootnote.setProperty('number'.toJS, value.number.toJS);
    return jsFootnote;
  }
  if (value == null) return null;
  print('Warning: Cannot convert type ${value.runtimeType} to JS.');
  return null;
}

TableColumnWidth reconstructTableColumnWidth(JSObject instance) {
  final type = (getProperty<JSString>(instance, "_type")!).toDart;
  switch (type) {
    case 'ScriptFixedColumnWidth':
      final width = (getProperty<JSNumber>(instance, 'width')!).toDartDouble;
      return FixedColumnWidth(width);
    case 'ScriptFlexColumnWidth':
      final flex = (getProperty<JSNumber>(instance, 'flex')!).toDartDouble;
      return FlexColumnWidth(flex);
    case 'ScriptIntrinsicColumnWidth':
      final flex = getProperty<JSNumber>(instance, 'flex')?.toDartDouble ?? 1.0;
      return IntrinsicColumnWidth(flex: flex);
  }
  print("couldnt not find table type");
  return FixedColumnWidth(0);
}
