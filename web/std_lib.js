// GENERATED CODE - DO NOT MODIFY BY HAND


// --- ENUMERATIONS ---

const BuiltInFontName = { helvetica: 'helvetica', helveticaBold: 'helveticaBold', helveticaOblique: 'helveticaOblique', helveticaBoldOblique: 'helveticaBoldOblique', times: 'times', timesBold: 'timesBold', timesItalic: 'timesItalic', timesBoldItalic: 'timesBoldItalic', courier: 'courier', courierBold: 'courierBold', courierOblique: 'courierOblique', courierBoldOblique: 'courierBoldOblique' };
const CrossAxisAlignment = { start: 'start', end: 'end', center: 'center', stretch: 'stretch' };
const FontStyle = { normal: 'normal', italic: 'italic' };
const FontWeight = { normal: 'normal', bold: 'bold' };
const LineBreakMode = { greedy: 'greedy', knuthPlass: 'knuthPlass' };
const MainAxisAlignment = { start: 'start', end: 'end', center: 'center' };
const MetadataRetrievalPolicy = { onPage: 'onPage', latest: 'latest', onPageThenLatest: 'onPageThenLatest' };
const PageNumberStyle = { arabic: 'arabic', romanLower: 'romanLower', romanUpper: 'romanUpper' };
const TableCellVerticalAlignment = { top: 'top', middle: 'middle', bottom: 'bottom', fill: 'fill' };
const TextDecoration = { none: 'none', underline: 'underline' };


// --- FACTORIES & HELPERS (IIFE) ---

const Align = (function() {
  function mainFactory(options) {
    const { alignment, child } = options || {};
    return {
      _type: 'ScriptAlign',
      alignment: alignment !== undefined ? alignment : { _type: 'ScriptAlignment', x: 0.0, y: 0.0 },
      child: child
    };
  };


  return mainFactory;
})();

const Alignment = (function() {
  function mainFactory(x, y) {
    return {
      _type: 'ScriptAlignment',
      x: x,
      y: y
    };
  };

  mainFactory.topLeft = mainFactory(-1.0, -1.0);
  mainFactory.topCenter = mainFactory(0.0, -1.0);
  mainFactory.topRight = mainFactory(1.0, -1.0);
  mainFactory.centerLeft = mainFactory(-1.0, 0.0);
  mainFactory.center = mainFactory(0.0, 0.0);
  mainFactory.centerRight = mainFactory(1.0, 0.0);
  mainFactory.bottomLeft = mainFactory(-1.0, 1.0);
  mainFactory.bottomCenter = mainFactory(0.0, 1.0);
  mainFactory.bottomRight = mainFactory(1.0, 1.0);

  return mainFactory;
})();

const Border = (function() {
  function mainFactory(options) {
    const { top, left, right, bottom } = options || {};
    return {
      _type: 'ScriptBorder',
      top: top !== undefined ? top : { _type: 'ScriptBorderSide', color: Color.black, width: 0.0 },
      left: left !== undefined ? left : { _type: 'ScriptBorderSide', color: Color.black, width: 0.0 },
      right: right !== undefined ? right : { _type: 'ScriptBorderSide', color: Color.black, width: 0.0 },
      bottom: bottom !== undefined ? bottom : { _type: 'ScriptBorderSide', color: Color.black, width: 0.0 }
    };
  };


  mainFactory.fromBorderSide = function(side) {
    return {
      _type: 'ScriptBorder',
      top: side,
      left: side,
      right: side,
      bottom: side
    };
  };

  mainFactory.all = function(options) {
    const { color, width } = options || {};
    return mainFactory.fromBorderSide(BorderSide({ color: color, width: width }));
  };

  return mainFactory;
})();

const BorderSide = (function() {
  function mainFactory(options) {
    const { color, width } = options || {};
    return {
      _type: 'ScriptBorderSide',
      color: color !== undefined ? color : { _type: 'ScriptColor', value: 4278190080 },
      width: width !== undefined ? width : 1.0
    };
  };

  mainFactory.none = mainFactory({ width: 0.0 });

  return mainFactory;
})();

const BoxDecoration = (function() {
  function mainFactory(options) {
    const { border } = options || {};
    return {
      _type: 'ScriptBoxDecoration',
      border: border
    };
  };


  return mainFactory;
})();

const Color = (function() {
  function mainFactory(value) {
    return {
      _type: 'ScriptColor',
      value: value
    };
  };

  mainFactory.black = mainFactory(4278190080);
  mainFactory.white = mainFactory(4294967295);
  mainFactory.red = mainFactory(4294901760);
  mainFactory.green = mainFactory(4278255360);
  mainFactory.blue = mainFactory(4278190335);

  mainFactory.fromHex = function(hexString) {
    return {
      _type: 'ScriptColor'
    };
  };

  return mainFactory;
})();

const Column = (function() {
  function mainFactory(options) {
    const { children, crossAxisAlignment, mainAxisAlignment } = options || {};
    return {
      _type: 'ScriptColumn',
      children: children !== undefined ? children : [],
      crossAxisAlignment: crossAxisAlignment !== undefined ? crossAxisAlignment : 'start',
      mainAxisAlignment: mainAxisAlignment !== undefined ? mainAxisAlignment : 'start'
    };
  };


  return mainFactory;
})();

const DecoratedBox = (function() {
  function mainFactory(options) {
    const { decoration, child } = options || {};
    return {
      _type: 'ScriptDecoratedBox',
      decoration: decoration,
      child: child
    };
  };


  return mainFactory;
})();

const Document = (function() {
  function mainFactory(options) {
    const { body, tocBuilder, pageFormat, pageMargin } = options || {};
    return {
      _type: 'ScriptDocument',
      body: body,
      tocBuilder: tocBuilder,
      pageFormat: pageFormat !== undefined ? pageFormat : { _type: 'ScriptPageFormat', width: 595.275590551181, height: 841.8897637795275 },
      pageMargin: pageMargin !== undefined ? pageMargin : EdgeInsets.all(30)
    };
  };


  return mainFactory;
})();

const DocumentMetadataRegistry = (function() {
  function mainFactory() {
    return {
      // ERROR: 'Could not resolve constructor AST.'
    };
  };


  return mainFactory;
})();

const EdgeInsets = (function() {
  function mainFactory() {
    throw new Error("EdgeInsets cannot be instantiated directly.");
  };


  mainFactory.fromLTRB = function(left, top, right, bottom) {
    return {
      _type: 'ScriptEdgeInsets',
      left: left,
      top: top,
      right: right,
      bottom: bottom
    };
  };

  mainFactory.zero = function() {
    return {
      _type: 'ScriptEdgeInsets',
      bottom: 0.0,
      top: 0.0,
      left: 0.0,
      right: 0.0
    };
  };

  mainFactory.all = function(value) {
    return mainFactory.fromLTRB(value, value, value, value);
  };

  mainFactory.symmetric = function(options) {
    const { horizontal, vertical } = options || {};
    return {
      _type: 'ScriptEdgeInsets',
      left: horizontal !== undefined ? horizontal : 0.0,
      right: horizontal !== undefined ? horizontal : 0.0,
      top: vertical !== undefined ? vertical : 0.0,
      bottom: vertical !== undefined ? vertical : 0.0
    };
  };

  mainFactory.only = function(options) {
    const { left, top, right, bottom } = options || {};
    return {
      _type: 'ScriptEdgeInsets',
      left: left !== undefined ? left : 0.0,
      top: top !== undefined ? top : 0.0,
      right: right !== undefined ? right : 0.0,
      bottom: bottom !== undefined ? bottom : 0.0
    };
  };

  return mainFactory;
})();

const Expanded = (function() {
  function mainFactory(options) {
    const { child, flex } = options || {};
    return {
      _type: 'ScriptExpanded',
      child: child,
      flex: flex !== undefined ? flex : 1
    };
  };


  return mainFactory;
})();

const FileImageSource = (function() {
  function mainFactory(path) {
    return {
      _type: 'ScriptFileImageSource',
      path: path
    };
  };


  return mainFactory;
})();

const FixedColumnWidth = (function() {
  function mainFactory(width) {
    return {
      _type: 'ScriptFixedColumnWidth',
      width: width
    };
  };


  return mainFactory;
})();

const FlexColumnWidth = (function() {
  function mainFactory(flex) {
    return {
      _type: 'ScriptFlexColumnWidth',
      flex: flex !== undefined ? flex : 1.0
    };
  };


  return mainFactory;
})();

const Flow = (function() {
  function mainFactory(options) {
    const { children } = options || {};
    return {
      _type: 'ScriptFlow',
      children: children !== undefined ? children : []
    };
  };


  return mainFactory;
})();

const FlowFill = (function() {
  function mainFactory(options) {
    const { child } = options || {};
    return {
      _type: 'ScriptFlowFill',
      child: child
    };
  };


  return mainFactory;
})();

const Font = (function() {
  function mainFactory() {
    return {
      _type: 'ScriptFont'
    };
  };

  mainFactory.helvetica = { _type: 'ScriptBuiltInFont', name: 'helvetica' };
  mainFactory.helveticaBold = { _type: 'ScriptBuiltInFont', name: 'helveticaBold' };
  mainFactory.helveticaOblique = { _type: 'ScriptBuiltInFont', name: 'helveticaOblique' };
  mainFactory.helveticaBoldOblique = { _type: 'ScriptBuiltInFont', name: 'helveticaBoldOblique' };
  mainFactory.times = { _type: 'ScriptBuiltInFont', name: 'times' };
  mainFactory.timesBold = { _type: 'ScriptBuiltInFont', name: 'timesBold' };
  mainFactory.timesItalic = { _type: 'ScriptBuiltInFont', name: 'timesItalic' };
  mainFactory.timesBoldItalic = { _type: 'ScriptBuiltInFont', name: 'timesBoldItalic' };
  mainFactory.courier = { _type: 'ScriptBuiltInFont', name: 'courier' };
  mainFactory.courierBold = { _type: 'ScriptBuiltInFont', name: 'courierBold' };
  mainFactory.courierOblique = { _type: 'ScriptBuiltInFont', name: 'courierOblique' };
  mainFactory.courierBoldOblique = { _type: 'ScriptBuiltInFont', name: 'courierBoldOblique' };

  return mainFactory;
})();

const FontFamily = (function() {
  function mainFactory(options) {
    const { regular, bold, italic, boldItalic } = options || {};
    return {
      _type: 'ScriptFontFamily',
      regular: regular,
      bold: bold,
      italic: italic,
      boldItalic: boldItalic
    };
  };

  mainFactory.helvetica = mainFactory({ regular: Font.helvetica, bold: Font.helveticaBold, italic: Font.helveticaOblique, boldItalic: Font.helveticaBoldOblique });
  mainFactory.times = mainFactory({ regular: Font.times, bold: Font.timesBold, italic: Font.timesItalic, boldItalic: Font.timesBoldItalic });
  mainFactory.courier = mainFactory({ regular: Font.courier, bold: Font.courierBold, italic: Font.courierOblique, boldItalic: Font.courierBoldOblique });

  mainFactory.fromFont = function(font) {
    return {
      _type: 'ScriptFontFamily'
    };
  };

  return mainFactory;
})();

const FootnoteItem = (function() {
  function mainFactory(options) {
    const { footnoteNumber, content } = options || {};
    return {
      _type: 'ScriptFootnoteItem',
      footnoteNumber: footnoteNumber,
      content: content
    };
  };


  return mainFactory;
})();

const FootnoteLayoutInfo = (function() {
  function mainFactory(options) {
    const { content, position, number } = options || {};
    return {
      _type: 'ScriptFootnoteLayoutInfo',
      content: content,
      position: position,
      number: number
    };
  };


  return mainFactory;
})();

const FormattedText = (function() {
  function mainFactory(text, options) {
    const { fontSize, fontFamily, lineHeight, builder, paragraphIndent, newlinesForBreak, indentFirstParagraph } = options || {};
    return {
      _type: 'ScriptFormattedText',
      text: text,
      fontSize: fontSize !== undefined ? fontSize : 12,
      fontFamily: fontFamily,
      lineHeight: lineHeight !== undefined ? lineHeight : 1.3,
      builder: builder,
      paragraphIndent: paragraphIndent,
      newlinesForBreak: newlinesForBreak !== undefined ? newlinesForBreak : 1,
      indentFirstParagraph: indentFirstParagraph !== undefined ? indentFirstParagraph : false
    };
  };


  return mainFactory;
})();

const Image = (function() {
  function mainFactory() {
    throw new Error("Image cannot be instantiated directly.");
  };


  mainFactory.memory = function(bytes, options) {
    const { width, height } = options || {};
    return {
      _type: 'ScriptImage'
    };
  };

  mainFactory.file = function(path, options) {
    const { width, height } = options || {};
    return {
      _type: 'ScriptImage'
    };
  };

  return mainFactory;
})();

const ImageSource = (function() {
  function mainFactory() {
    return {
      _type: 'ScriptImageSource'
    };
  };


  return mainFactory;
})();

const IntrinsicColumnWidth = (function() {
  function mainFactory(options) {
    const { flex } = options || {};
    return {
      _type: 'ScriptIntrinsicColumnWidth',
      flex: flex !== undefined ? flex : 1.0
    };
  };


  return mainFactory;
})();

const KeepTogether = (function() {
  function mainFactory(options) {
    const { first, second } = options || {};
    return {
      _type: 'ScriptKeepTogether',
      first: first,
      second: second
    };
  };


  return mainFactory;
})();

const LineBreakConfiguration = (function() {
  function mainFactory(options) {
    const { mode, child } = options || {};
    return {
      _type: 'ScriptLineBreakConfiguration',
      mode: mode,
      child: child
    };
  };


  return mainFactory;
})();

const MemoryImageSource = (function() {
  function mainFactory(bytes) {
    return {
      _type: 'ScriptMemoryImageSource',
      bytes: bytes
    };
  };


  return mainFactory;
})();

const MetadataMarker = (function() {
  function mainFactory(options) {
    const { key, value, child } = options || {};
    return {
      _type: 'ScriptMetadataMarker',
      key: key,
      value: value,
      child: child
    };
  };


  return mainFactory;
})();

const MetadataRecord = (function() {
  function mainFactory(options) {
    const { key, value, pageNumber } = options || {};
    return {
      _type: 'ScriptMetadataRecord',
      key: key,
      value: value,
      pageNumber: pageNumber
    };
  };


  return mainFactory;
})();

const MultiColumn = (function() {
  function mainFactory(options) {
    const { columnCount, columnSpacing, children } = options || {};
    return {
      _type: 'ScriptMultiColumn',
      columnCount: columnCount !== undefined ? columnCount : 2,
      columnSpacing: columnSpacing !== undefined ? columnSpacing : 10.0,
      children: children !== undefined ? children : []
    };
  };


  return mainFactory;
})();

const MultiColumnFlow = (function() {
  function mainFactory(options) {
    const { columnCount, columnSpacing, children } = options || {};
    return {
      _type: 'ScriptMultiColumnFlow',
      columnCount: columnCount !== undefined ? columnCount : 2,
      columnSpacing: columnSpacing !== undefined ? columnSpacing : 10.0,
      children: children !== undefined ? children : []
    };
  };


  return mainFactory;
})();

const Padding = (function() {
  function mainFactory(options) {
    const { padding, child } = options || {};
    return {
      _type: 'ScriptPadding',
      padding: padding,
      child: child
    };
  };


  return mainFactory;
})();

const PageContext = (function() {
  function mainFactory(options) {
    const { pageNumber, totalPages, formattedPageNumber, formattedTotalPages, sectionPageCount } = options || {};
    return {
      _type: 'ScriptPageContext',
      pageNumber: pageNumber,
      totalPages: totalPages,
      formattedPageNumber: formattedPageNumber,
      formattedTotalPages: formattedTotalPages,
      sectionPageCount: sectionPageCount
    };
  };


  return mainFactory;
})();

const PageFormat = (function() {
  function mainFactory(width, height) {
    return {
      _type: 'ScriptPageFormat',
      width: width,
      height: height
    };
  };

  const point = 1.0;
  const inch = 72.0;
  const cm = 28.346456692913385;
  const mm = 2.834645669291339;
  const dp = 0.48;
  mainFactory.a3 = mainFactory(841.8897637795275, 1190.551181102362);
  mainFactory.a4 = mainFactory(595.275590551181, 841.8897637795275);
  mainFactory.a5 = mainFactory(419.5275590551181, 595.275590551181);
  mainFactory.a6 = mainFactory(297.6377952755906, 419.52755905511816);
  mainFactory.letter = mainFactory(612.0, 792.0);
  mainFactory.legal = mainFactory(612.0, 1008.0);
  mainFactory.standard = mainFactory(595.275590551181, 841.8897637795275);
  mainFactory.point = 1.0;
  mainFactory.inch = 72.0;
  mainFactory.cm = 28.346456692913385;
  mainFactory.mm = 2.834645669291339;
  mainFactory.dp = 0.48;

  return mainFactory;
})();

const PageLayout = (function() {
  function mainFactory(options) {
    const { header, footer, body, footnoteBuilder } = options || {};
    return {
      _type: 'ScriptPageLayout',
      header: header,
      footer: footer,
      body: body !== undefined ? body : [],
      footnoteBuilder: footnoteBuilder
    };
  };


  return mainFactory;
})();

const PageNumberSettings = (function() {
  function mainFactory(options) {
    const { style, startAt } = options || {};
    return {
      _type: 'ScriptPageNumberSettings',
      style: style !== undefined ? style : 'arabic',
      startAt: startAt !== undefined ? startAt : 1
    };
  };


  return mainFactory;
})();

const PageSection = (function() {
  function mainFactory() {
    throw new Error("PageSection cannot be instantiated directly.");
  };


  mainFactory.fixed = function(options) {
    const { height, builder } = options || {};
    return {
      _type: 'ScriptPageSection',
      height: height,
      builder: builder,
      prototype: null
    };
  };

  mainFactory.prototyped = function(options) {
    const { prototype, builder } = options || {};
    return {
      _type: 'ScriptPageSection',
      prototype: prototype,
      builder: builder,
      height: null
    };
  };

  return mainFactory;
})();

const Repeater = (function() {
  function mainFactory(text, options) {
    const { fontSize, font, lineHeight } = options || {};
    return {
      _type: 'ScriptRepeater',
      text: text,
      fontSize: fontSize !== undefined ? fontSize : 12,
      font: font,
      lineHeight: lineHeight !== undefined ? lineHeight : 1.3
    };
  };


  return mainFactory;
})();

const ResetPageNumber = (function() {
  function mainFactory(options) {
    const { style, startAt } = options || {};
    return {
      _type: 'ScriptResetPageNumber',
      style: style !== undefined ? style : 'arabic',
      startAt: startAt !== undefined ? startAt : 1
    };
  };


  return mainFactory;
})();

const RichText = (function() {
  function mainFactory(options) {
    const { children, fontSize, font, lineHeight } = options || {};
    return {
      _type: 'ScriptRichText',
      children: children,
      fontSize: fontSize !== undefined ? fontSize : 12,
      font: font,
      lineHeight: lineHeight !== undefined ? lineHeight : 1.3
    };
  };


  return mainFactory;
})();

const Row = (function() {
  function mainFactory(options) {
    const { children } = options || {};
    return {
      _type: 'ScriptRow',
      children: children !== undefined ? children : []
    };
  };


  return mainFactory;
})();

const Size = (function() {
  function mainFactory(width, height) {
    return {
      _type: 'ScriptSize',
      width: width,
      height: height
    };
  };

  mainFactory.zero = mainFactory(0.0, 0.0);

  return mainFactory;
})();

const SizedBox = (function() {
  function mainFactory(options) {
    const { width, height, child } = options || {};
    return {
      _type: 'ScriptSizedBox',
      width: width,
      height: height,
      child: child
    };
  };


  mainFactory.shrink = function() {
    return {
      _type: 'ScriptSizedBox',
      width: 0.0,
      height: 0.0,
      child: null
    };
  };

  return mainFactory;
})();

const SyncedColumns = (function() {
  function mainFactory(options) {
    const { topChildren, topColumnCount, topColumnSpacing, bottomChildren, bottomColumnCount, bottomColumnSpacing, spacing } = options || {};
    return {
      _type: 'ScriptSyncedColumns',
      topChildren: topChildren !== undefined ? topChildren : [],
      topColumnCount: topColumnCount !== undefined ? topColumnCount : 2,
      topColumnSpacing: topColumnSpacing !== undefined ? topColumnSpacing : 10.0,
      bottomChildren: bottomChildren !== undefined ? bottomChildren : [],
      bottomColumnCount: bottomColumnCount !== undefined ? bottomColumnCount : 2,
      bottomColumnSpacing: bottomColumnSpacing !== undefined ? bottomColumnSpacing : 10.0,
      spacing: spacing !== undefined ? spacing : 20.0
    };
  };


  return mainFactory;
})();

const Table = (function() {
  function mainFactory(options) {
    const { children, columnWidths, defaultVerticalAlignment } = options || {};
    return {
      _type: 'ScriptTable',
      children: children !== undefined ? children : [],
      columnWidths: columnWidths !== undefined ? columnWidths : {},
      defaultVerticalAlignment: defaultVerticalAlignment !== undefined ? defaultVerticalAlignment : 'top'
    };
  };


  return mainFactory;
})();

const TableCell = (function() {
  function mainFactory(options) {
    const { child, rowSpan, colSpan, verticalAlignment } = options || {};
    return {
      _type: 'ScriptTableCell',
      child: child,
      rowSpan: rowSpan !== undefined ? rowSpan : 1,
      colSpan: colSpan !== undefined ? colSpan : 1,
      verticalAlignment: verticalAlignment !== undefined ? verticalAlignment : 'top'
    };
  };


  return mainFactory;
})();

const TableColumnWidth = (function() {
  function mainFactory() {
    return {
      _type: 'ScriptTableColumnWidth'
    };
  };


  return mainFactory;
})();

const TableRow = (function() {
  function mainFactory(options) {
    const { children } = options || {};
    return {
      _type: 'ScriptTableRow',
      children: children !== undefined ? children : []
    };
  };


  return mainFactory;
})();

const Text = (function() {
  function mainFactory(text, options) {
    const { style, fontSize, font, lineHeight } = options || {};
    return {
      _type: 'ScriptText',
      text: text,
      style: style !== undefined ? style : TextStyle(),
      fontSize: fontSize,
      font: font,
      lineHeight: lineHeight !== undefined ? lineHeight : 1.3
    };
  };


  return mainFactory;
})();

const TextSpan = (function() {
  function mainFactory(text, options) {
    const { style, metadata } = options || {};
    return {
      _type: 'ScriptTextSpan',
      text: text,
      metadata: metadata,
      style: style ?? TextStyle.normal
    };
  };


  return mainFactory;
})();

const TextStyle = (function() {
  function mainFactory(options) {
    const { fontSize, fontFamily, fontWeight, fontStyle, yOffsetFactor, decoration, decorationColor, decorationThickness, leftPadding, textColor } = options || {};
    return {
      _type: 'ScriptTextStyle',
      fontSize: fontSize,
      fontFamily: fontFamily,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      yOffsetFactor: yOffsetFactor,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationThickness: decorationThickness,
      leftPadding: leftPadding,
      textColor: textColor
    };
  };

  mainFactory.normal = mainFactory({ fontSize: 12.0, fontFamily: null, fontWeight: 'normal', fontStyle: 'normal', yOffsetFactor: 0.0, decoration: 'none', leftPadding: 0.0 });
  mainFactory.large = mainFactory({ fontSize: 14.0 });
  mainFactory.superscript = mainFactory({ fontSize: 8.0, yOffsetFactor: 0.4 });

  mainFactory.fromFont = function(options) {
    const { font, fontSize, fontWeight, fontStyle, yOffsetFactor, decoration, decorationColor, decorationThickness, leftPadding, textColor } = options || {};
    return {
      _type: 'ScriptTextStyle',
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      yOffsetFactor: yOffsetFactor,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationThickness: decorationThickness,
      leftPadding: leftPadding,
      textColor: textColor,
      fontFamily: font != null ? FontFamily.fromFont(font) : FontFamily.fromFont(Font.helvetica)
    };
  };

  return mainFactory;
})();

const TtfFont = (function() {
  function mainFactory(path) {
    return {
      _type: 'ScriptTtfFont',
      path: path
    };
  };


  return mainFactory;
})();

const Underline = (function() {
  function mainFactory(options) {
    const { child, color, thickness } = options || {};
    return {
      _type: 'ScriptUnderline',
      child: child,
      color: color !== undefined ? color : { _type: 'ScriptColor', value: 4278190080 },
      thickness: thickness !== undefined ? thickness : 1.0
    };
  };


  return mainFactory;
})();

const BuiltInFont = (function() {
  function mainFactory(name) {
    return {
      _type: 'ScriptBuiltInFont',
      name: name
    };
  };


  return mainFactory;
})();


// --- Helpers ---
function getMetadata(context, key, policy = MetadataRetrievalPolicy.onPageThenLatest) {
    if (!context || !context.metadata) return [];
    switch (policy) {
        case MetadataRetrievalPolicy.onPage:
            return context.metadata.filter(r => r.key === key && r.pageNumber === context.pageNumber).map(r => r.value);
        case MetadataRetrievalPolicy.latest:
            const record = context.metadata.slice().reverse().find(r => r.key === key && r.pageNumber <= context.pageNumber);
            return record ? [record.value] : [];
        case MetadataRetrievalPolicy.onPageThenLatest:
            const onPageResults = getMetadata(context, key, MetadataRetrievalPolicy.onPage);
            if (onPageResults.length > 0) return onPageResults;
            return getMetadata(context, key, MetadataRetrievalPolicy.latest);
    }
    return [];
}

// --- API Contract ---
function defineDocument() { throw new Error("User script must define a 'defineDocument' function."); }

