import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../typesetting_prototype.dart';
import '../platform/pdf_saver.dart';

class Document {
  final PageLayout body;
  final PageLayout Function(DocumentMetadataRegistry registry)? tocBuilder;
  final PageFormat pageFormat;
  final EdgeInsets pageMargin;

  Document({
    required this.body,
    this.tocBuilder,
    this.pageFormat = PageFormat.a4,
    this.pageMargin = const EdgeInsets.all(30),
  });

  Future<Uint8List> save() async {
    final pdf = pw.Document();
    final sharedPwContext = pw.Context(document: pdf.document);

    final contentWidth = pageFormat.width - pageMargin.horizontal;
    final contentHeight = pageFormat.height - pageMargin.vertical;
    final pageConstraints = BoxConstraints(maxWidth: contentWidth, maxHeight: contentHeight);
    final sharedLayoutContext = LayoutContext(pwContext: sharedPwContext, constraints: pageConstraints, metadata: []);

    final bodyLayout = body.createRenderNode() as RenderPageLayout;
    final rawBodyRecords = bodyLayout.buildPages(sharedLayoutContext);
    final bodyPageCount = bodyLayout.pageCount;

    int tocPageCount = 0;
    if (tocBuilder != null) {
      final tempRegistry = DocumentMetadataRegistry()..records.addAll(rawBodyRecords);
      final tempTocWidget = tocBuilder!(tempRegistry);
      final tempTocLayout = tempTocWidget.createRenderNode() as RenderPageLayout;
      tempTocLayout.buildPages(sharedLayoutContext);
      tocPageCount = tempTocLayout.pageCount;
    }
    final totalPages = tocPageCount + bodyPageCount;

    final finalRegistry = DocumentMetadataRegistry();
    finalRegistry.records.addAll(rawBodyRecords);

    finalRegistry.finalizePageNumbers(tocPageCount);

    final bodyPageNumberMap = bodyLayout.generatePageNumberMap(pageNumberOffset: tocPageCount);

    finalRegistry.updateFormattedNumbers(bodyPageNumberMap);

    bodyLayout.finalizeFrames(
      layoutContext: sharedLayoutContext,
      totalPages: totalPages,
      pageNumberOffset: tocPageCount,
      allRecords: finalRegistry.records,
      pageNumberMap: bodyPageNumberMap,
    );

    RenderPageLayout? finalTocLayout;
    if (tocBuilder != null) {
      final finalTocWidget = tocBuilder!(finalRegistry);
      finalTocLayout = finalTocWidget.createRenderNode() as RenderPageLayout;
      finalTocLayout.buildPages(sharedLayoutContext);

      final tocPageNumberMap = finalTocLayout.generatePageNumberMap(pageNumberOffset: 0);

      finalTocLayout.finalizeFrames(
        layoutContext: sharedLayoutContext,
        totalPages: totalPages,
        pageNumberOffset: 0,
        allRecords: finalRegistry.records,
        pageNumberMap: tocPageNumberMap,
      );
    }

    for (int i = 0; i < tocPageCount; i++) {
      pdf.addPage(_buildPdfPage(pageConstraints, (context) => finalTocLayout!.paintPage(i, context)));
    }
    for (int i = 0; i < bodyPageCount; i++) {
      pdf.addPage(_buildPdfPage(pageConstraints, (context) => bodyLayout.paintPage(i, context)));
    }

    return pdf.save();
  }

  pw.Page _buildPdfPage(BoxConstraints constraints, Function(PaintingContext) painter) {
    return pw.Page(
      margin: pw.EdgeInsets.fromLTRB(pageMargin.left, pageMargin.top, pageMargin.right, pageMargin.bottom),
      pageFormat: PdfPageFormat(pageFormat.width, pageFormat.height),
      build: (pw.Context context) {
        return pw.CustomPaint(
          size: PdfPoint(constraints.maxWidth, constraints.maxHeight),
          painter: (PdfGraphics canvas, PdfPoint size) {
            final paintingContext = PaintingContext(context, canvas, pageHeight: size.y);
            painter(paintingContext);
          },
        );
      },
    );
  }
}

class PageFormat {
  const PageFormat(this.width, this.height);

  static const PageFormat a3 = PageFormat(29.7 * cm, 42 * cm);
  static const PageFormat a4 = PageFormat(21.0 * cm, 29.7 * cm);
  static const PageFormat a5 = PageFormat(14.8 * cm, 21.0 * cm);
  static const PageFormat a6 = PageFormat(105 * mm, 148 * mm);
  static const PageFormat letter = PageFormat(8.5 * inch, 11.0 * inch);
  static const PageFormat legal = PageFormat(8.5 * inch, 14.0 * inch);

  static const PageFormat roll57 = PageFormat(57 * mm, double.infinity);
  static const PageFormat roll80 = PageFormat(80 * mm, double.infinity);

  static const PageFormat undefined = PageFormat(double.infinity, double.infinity);

  static const PageFormat standard = a4;

  static const double point = 1.0;
  static const double inch = 72.0;
  static const double cm = inch / 2.54;
  static const double mm = inch / 25.4;

  static const double dp = 72.0 / 150.0;

  final double width;
  final double height;

  PageFormat copyWith({
    double? width,
    double? height,
    double? marginTop,
    double? marginBottom,
    double? marginLeft,
    double? marginRight,
  }) {
    return PageFormat(width ?? this.width, height ?? this.height);
  }

  Size get dimension => Size(width, height);

  PageFormat get landscape => width >= height ? this : copyWith(width: height, height: width);

  PageFormat get portrait => height >= width ? this : copyWith(width: height, height: width);
}

class PdfGenerator {
  static Future<void> generatePdf(Document document, String path) async {
    final bytes = await document.save();

    await savePdfPlatformSpecific(bytes, path);
  }

  static Future<void> generatePwPdf(pw.Document document, String path) async {
    final bytes = await document.save();

    await savePdfPlatformSpecific(bytes, path);
  }
}
