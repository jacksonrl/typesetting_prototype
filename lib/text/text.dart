import 'dart:math';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../knuth/knuth_plass_span_multi_font_size.dart';

import '../typesetting_prototype.dart';

enum TextDecoration { none, underline }

class TextStyle {
  final double? fontSize;
  final FontFamily? fontFamily;
  final FontWeight? fontWeight;
  final FontStyle? fontStyle;
  final double? yOffsetFactor;
  final TextDecoration? decoration;
  final Color? decorationColor;
  final double? decorationThickness;
  final double? leftPadding;
  final Color? textColor;

  const TextStyle({
    this.fontSize,
    this.fontFamily,
    this.fontWeight,
    this.fontStyle,
    this.yOffsetFactor,
    this.decoration,
    this.decorationColor,
    this.decorationThickness,
    this.leftPadding,
    this.textColor,
  });

  // Helper constructor for the old API
  TextStyle.fromFont({
    Font? font,
    this.fontSize,
    this.fontWeight,
    this.fontStyle,
    this.yOffsetFactor,
    this.decoration,
    this.decorationColor,
    this.decorationThickness,
    this.leftPadding,
    this.textColor,
  }) : fontFamily = font != null ? FontFamily.fromFont(font) : FontFamily.fromFont(Font.helvetica);

  static const TextStyle normal = TextStyle(
    fontSize: 12.0,
    fontFamily: null,
    fontWeight: FontWeight.normal,
    fontStyle: FontStyle.normal,
    yOffsetFactor: 0.0,
    decoration: TextDecoration.none,
    leftPadding: 0.0,
  );
  static const TextStyle large = TextStyle(fontSize: 14.0);
  static const TextStyle superscript = TextStyle(fontSize: 8.0, yOffsetFactor: 0.4);

  /// Merges this style with another. Properties from [other] take precedence.
  TextStyle merge(TextStyle? other) {
    if (other == null) return this;
    return TextStyle(
      fontSize: other.fontSize ?? fontSize,
      fontFamily: other.fontFamily ?? fontFamily,
      fontWeight: other.fontWeight ?? fontWeight,
      fontStyle: other.fontStyle ?? fontStyle,
      yOffsetFactor: other.yOffsetFactor ?? yOffsetFactor,
      decoration: other.decoration ?? decoration,
      decorationColor: other.decorationColor ?? decorationColor,
      decorationThickness: other.decorationThickness ?? decorationThickness,
      leftPadding: other.leftPadding ?? leftPadding,
      textColor: other.textColor ?? textColor,
    );
  }

  /// Creates a fully resolved style with no null values by merging with a default.
  ResolvedTextStyle resolve() {
    final defaultStyle = ResolvedTextStyle.defaults;
    return ResolvedTextStyle(
      font: fontFamily != null
          ? fontFamily!.getVariant(fontWeight ?? FontWeight.normal, fontStyle ?? FontStyle.normal)
          : Font.helvetica,
      fontSize: fontSize ?? defaultStyle.fontSize,
      yOffsetFactor: yOffsetFactor ?? defaultStyle.yOffsetFactor,
      decoration: decoration ?? defaultStyle.decoration,
      decorationColor: decorationColor ?? defaultStyle.decorationColor,
      decorationThickness: decorationThickness ?? defaultStyle.decorationThickness,
      leftPadding: leftPadding ?? defaultStyle.leftPadding,
      textColor: textColor ?? defaultStyle.textColor,
    );
  }
}

///Used by MakeParagraph and below. The main difference is all
///fields are gaurenteed not to be null and the font family,
///style and weight values are resolved to a single final font.
class ResolvedTextStyle {
  final double fontSize;
  final double yOffsetFactor;
  final Font font;
  final TextDecoration decoration;
  final Color decorationColor;
  final double decorationThickness;
  final double leftPadding;
  final Color textColor;

  const ResolvedTextStyle({
    required this.fontSize,
    required this.yOffsetFactor,
    required this.font,
    required this.decoration,
    required this.decorationColor,
    required this.decorationThickness,
    required this.leftPadding,
    required this.textColor,
  });

  /// The default values for the entire document.
  static final defaults = ResolvedTextStyle(
    fontSize: 12.0,
    yOffsetFactor: 0.0,
    font: Font.helvetica,
    decoration: TextDecoration.none,
    decorationColor: Color.black,
    decorationThickness: 1.0,
    leftPadding: 0.0,
    textColor: Color.black,
  );
}

class TextSpan {
  final String text;
  final TextStyle style;
  final List<MetadataRecord>? metadata;

  TextSpan(this.text, {TextStyle? style, this.metadata}) : style = style ?? TextStyle.normal;
}

enum LineBreakMode { greedy, knuthPlass }

class LineBreakSettings {
  final LineBreakMode mode;

  const LineBreakSettings({this.mode = LineBreakMode.greedy});

  static const LineBreakSettings defaultSettings = LineBreakSettings();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is LineBreakSettings && runtimeType == other.runtimeType && mode == other.mode;

  @override
  int get hashCode => mode.hashCode;
}

class RenderRichTextLine extends RenderNode {
  final List<TextSpan> spans;
  final double fixedHeight;

  RenderRichTextLine(this.spans, {required this.fixedHeight});

  @override
  LayoutResult performLayout() {
    double totalWidth = 0;
    if (spans.isNotEmpty) {
      totalWidth += spans.first.style.resolve().leftPadding;
    }

    for (final span in spans) {
      final style = span.style.resolve();
      final pdfFont = FontManager.getFont(style.font, layoutContext!.pwContext);
      totalWidth += pdfFont.stringMetrics(span.text).width * style.fontSize;
    }
    size = constraints!.constrain(Size(totalWidth, fixedHeight));
    return LayoutResult(size: size);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    double currentX = offset.dx;
    if (spans.isNotEmpty) {
      currentX += spans.first.style.resolve().leftPadding;
    }

    double maxAscent = 0;
    for (final span in spans) {
      final style = span.style.resolve();
      final pdfFont = FontManager.getFont(style.font, context.pdfContext);
      maxAscent = max(maxAscent, pdfFont.ascent * style.fontSize);
    }
    final primaryBaselineY = context.pageHeight - offset.dy - maxAscent;

    for (final span in spans) {
      final style = span.style.resolve();
      if (span.text.isEmpty) continue;

      final pdfFont = FontManager.getFont(style.font, context.pdfContext);
      final textWidth = pdfFont.stringMetrics(span.text).width * style.fontSize;

      final yOffset = style.yOffsetFactor * style.fontSize;
      final spanBaselineY = primaryBaselineY + yOffset;
      context.canvas.setColor(PdfColor.fromInt(style.textColor.value));
      context.canvas.drawString(pdfFont, style.fontSize, span.text, currentX, spanBaselineY);

      if (style.decoration == TextDecoration.underline) {
        final underlineY = spanBaselineY - (style.fontSize * 0.15);
        final lineEndX = currentX + textWidth;
        context.canvas
          ..saveContext()
          ..setStrokeColor(PdfColor.fromInt(style.decorationColor.value))
          ..setLineWidth(style.decorationThickness)
          ..moveTo(currentX, underlineY)
          ..lineTo(lineEndX, underlineY)
          ..strokePath()
          ..restoreContext();
      }
      currentX += textWidth;
    }
  }
}

class RenderKnuthPlassTextLine extends RenderNode {
  final double maxFontSizeInLine;
  final double fixedHeight;
  final List<Specification> line;
  final double ratio;

  RenderKnuthPlassTextLine({
    required this.maxFontSizeInLine,
    required this.fixedHeight,
    required this.line,
    required this.ratio,
  });

  @override
  void paint(PaintingContext context, Offset offset) {
    //TODO: pick largest height from fonts in line.
    final firstFontHeightFont = (line.firstWhere((s) => s is Box) as Box).style.font;
    final firstFontHeight = FontManager.getFont(firstFontHeightFont, context.pdfContext);

    final y = context.pageHeight - offset.dy - (firstFontHeight.ascent * maxFontSizeInLine);
    double currentX = 0;
    ResolvedTextStyle? underlineStyle;
    bool isUnderlineSpan = false;

    for (int k = 0; k < line.length; k++) {
      final spec = line[k];
      final isLastItemInLine = k == line.length - 1;

      if (spec.isBox) {
        final box = spec as Box;
        final style = box.style;
        final yOffset = style.yOffsetFactor * style.fontSize;
        context.canvas.drawString(
          FontManager.getFont(style.font, context.pdfContext),
          style.fontSize,
          box.value,
          offset.dx + currentX,
          y + yOffset,
        );

        if (style.decoration == TextDecoration.underline) {
          final textX = offset.dx + currentX;
          final underlineY = y - (style.fontSize * 0.15);
          final lineEndX = textX + box.width;
          isUnderlineSpan = true;
          underlineStyle = style;

          context.canvas
            ..saveContext()
            ..setStrokeColor(PdfColor.fromInt(style.decorationColor.value))
            ..setLineWidth(style.decorationThickness)
            ..moveTo(textX, underlineY)
            ..lineTo(lineEndX, underlineY)
            ..strokePath()
            ..restoreContext();
        } else {
          isUnderlineSpan = false;
          underlineStyle = null;
        }
        currentX += box.width;
      } else if (spec.isGlue) {
        if (!isLastItemInLine) {
          final glue = spec as Glue;
          final spaceWidth = glue.rWidth(ratio);
          if (isUnderlineSpan) {
            final textX = offset.dx + currentX;
            final underlineY = y - (underlineStyle!.fontSize * 0.15);
            final lineEndX = textX + glue.width;
            context.canvas
              ..saveContext()
              ..setStrokeColor(PdfColor.fromInt(underlineStyle.decorationColor.value))
              ..setLineWidth(underlineStyle.decorationThickness)
              ..moveTo(textX, underlineY)
              ..lineTo(lineEndX, underlineY)
              ..strokePath()
              ..restoreContext();
          }
          currentX += spaceWidth;
        }
      } else if (spec is Penalty && spec.isHyphen && isLastItemInLine) {
        ResolvedTextStyle hyphenStyle = ResolvedTextStyle.defaults;
        if (k > 0 && line[k - 1] is Box) {
          hyphenStyle = (line[k - 1] as Box).style;
        }
        context.canvas.drawString(
          FontManager.getFont(hyphenStyle.font, context.pdfContext),
          hyphenStyle.fontSize,
          '-',
          offset.dx + currentX,
          y,
        );
      }
    }
  }

  @override
  LayoutResult performLayout() {
    size = constraints!.constrain(Size(constraints!.maxWidth, fixedHeight));
    return (LayoutResult(size: size));
  }
}

class RenderRichText extends RenderNode with ContainerRenderNodeMixin, RenderSlice {
  final List<TextSpan> spans;
  final double fontSize;
  final double lineHeight;
  RenderRichText(this.spans, {required this.fontSize, required this.lineHeight});

  @override
  LayoutResult performLayout() {
    final lineBreakSettings = getLineBreakSettings();
    final lineBreakMode = lineBreakSettings.mode;

    final wrapResult = TextWrapper.wrap(
      mode: lineBreakMode,
      spans: spans,
      fontSize: fontSize, // This is a fallback/default
      maxWidth: constraints!.maxWidth,
      pwContext: layoutContext!.pwContext,
    );

    clear();
    double totalHeight = 0;

    if (lineBreakMode == LineBreakMode.greedy) {
      final greedyResult = wrapResult as GreedyWrapResult;
      for (final lineSpans in greedyResult.lines) {
        double maxFontSizeInLine = 0.0;
        for (final span in lineSpans) {
          maxFontSizeInLine = max(maxFontSizeInLine, span.style.resolve().fontSize);
        }
        if (maxFontSizeInLine == 0) maxFontSizeInLine = fontSize;
        final fixedLineHeightFont = spans.first.style.resolve().font;
        final fixedLineHeight =
            FontManager.getFont(fixedLineHeightFont, layoutContext!.pwContext).emptyLineHeight *
            maxFontSizeInLine *
            lineHeight;

        add(RenderRichTextLine(lineSpans, fixedHeight: fixedLineHeight));
      }
    } else if (lineBreakMode == LineBreakMode.knuthPlass) {
      final kpWrapResult = wrapResult as KnuthPlassWrapResult;
      for (int i = 0; i < kpWrapResult.specifications.length; i++) {
        final lineSpecs = kpWrapResult.specifications[i];

        double maxFontSizeInLine = 0.0;
        for (final spec in lineSpecs) {
          if (spec is Box) {
            maxFontSizeInLine = max(maxFontSizeInLine, spec.style.fontSize);
          }
        }
        if (maxFontSizeInLine == 0.0) maxFontSizeInLine = fontSize;
        final fixedLineHeightFont = spans.first.style.resolve().font;
        final fixedLineHeight =
            FontManager.getFont(fixedLineHeightFont, layoutContext!.pwContext).emptyLineHeight *
            maxFontSizeInLine *
            lineHeight;

        add(
          RenderKnuthPlassTextLine(
            line: lineSpecs,
            ratio: kpWrapResult.ratios[i],
            maxFontSizeInLine: maxFontSizeInLine,
            fixedHeight: fixedLineHeight,
          ),
        );
      }
    }

    double maxWidth = 0;
    final childLayoutContext = layoutContext!.copyWith(constraints: BoxConstraints(maxWidth: constraints!.maxWidth));
    for (final child in children) {
      child.layout(childLayoutContext);
      totalHeight += child.size.height;
      if (child.size.width > maxWidth) {
        maxWidth = child.size.width;
      }
    }
    size = Size(maxWidth, totalHeight);
    return LayoutResult(size: size);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    double currentY = 0;
    for (final child in children) {
      child.paint(context, offset + Offset(0, currentY));
      currentY += child.size.height;
    }
  }

  @override
  SliceLayoutResult layoutSlice(SliceLayoutContext context) {
    final lineBreakSettings = getLineBreakSettings();
    final lineBreakMode = lineBreakSettings.mode;

    final wrapResult = TextWrapper.wrap(
      mode: lineBreakMode,
      spans: spans,
      fontSize: fontSize,
      maxWidth: context.constraints.maxWidth,
      pwContext: context.pwContext,
    );

    final List<PositionedPrimitive> placedLines = [];
    final List<MetadataRecord> metadataForThisSlice = [];
    double currentY = 0;
    double maxWidth = 0;
    WrapResult? remainingTextLines;

    final childLayoutContext = LayoutContext(
      pwContext: context.pwContext,
      constraints: context.constraints,
      metadata: context.metadata,
    );

    if (lineBreakMode == LineBreakMode.greedy) {
      final greedyResult = wrapResult as GreedyWrapResult;
      for (int i = 0; i < greedyResult.lines.length; i++) {
        final lineSpans = greedyResult.lines[i];

        double maxFontSizeInLine = 0.0;
        for (final span in lineSpans) {
          maxFontSizeInLine = max(maxFontSizeInLine, span.style.resolve().fontSize);
        }
        if (maxFontSizeInLine == 0) maxFontSizeInLine = fontSize;
        final dynamicLineHeightFont = spans.first.style.resolve().font;
        final dynamicLineHeight =
            FontManager.getFont(dynamicLineHeightFont, context.pwContext).emptyLineHeight *
            maxFontSizeInLine *
            lineHeight;

        if (currentY + dynamicLineHeight <= context.availableHeight) {
          for (final span in lineSpans) {
            if (span.metadata != null) {
              metadataForThisSlice.addAll(span.metadata!);
            }
          }

          final lineNode = RenderRichTextLine(lineSpans, fixedHeight: dynamicLineHeight);
          lineNode.layout(childLayoutContext);
          placedLines.add(PositionedPrimitive(lineNode, Offset(0, currentY)));
          currentY += dynamicLineHeight;
          if (lineNode.size.width > maxWidth) maxWidth = lineNode.size.width;
        } else {
          remainingTextLines = GreedyWrapResult(greedyResult.lines.sublist(i));
          break;
        }
      }
    } else if (lineBreakMode == LineBreakMode.knuthPlass) {
      final kpWrapResult = wrapResult as KnuthPlassWrapResult;
      for (int i = 0; i < kpWrapResult.specifications.length; i++) {
        final lineSpecs = kpWrapResult.specifications[i];
        double maxFontSizeInLine = 0.0;
        for (final spec in lineSpecs) {
          if (spec is Box) {
            maxFontSizeInLine = max(maxFontSizeInLine, spec.style.fontSize);
          }
        }
        if (maxFontSizeInLine == 0.0) maxFontSizeInLine = fontSize;
        //TODO use largest font type instead
        final firstFontHeightFont = (lineSpecs.firstWhere((s) => s is Box) as Box).style.font;
        final firstFontHeight = FontManager.getFont(firstFontHeightFont, context.pwContext);
        final dynamicLineHeight = firstFontHeight.emptyLineHeight * maxFontSizeInLine * lineHeight;

        if (currentY + dynamicLineHeight <= context.availableHeight) {
          for (final spec in lineSpecs) {
            if (spec is Box && spec.sourceSpan?.metadata != null) {
              metadataForThisSlice.addAll(spec.sourceSpan!.metadata!);
            }
          }

          final lineNode = RenderKnuthPlassTextLine(
            line: lineSpecs,
            ratio: kpWrapResult.ratios[i],
            maxFontSizeInLine: maxFontSizeInLine,
            fixedHeight: dynamicLineHeight,
          );
          lineNode.layout(childLayoutContext);
          placedLines.add(PositionedPrimitive(lineNode, Offset(0, currentY)));
          currentY += dynamicLineHeight;
          if (lineNode.size.width > maxWidth) maxWidth = lineNode.size.width;
        } else {
          remainingTextLines = KnuthPlassWrapResult(
            specifications: kpWrapResult.specifications.sublist(i),
            ratios: kpWrapResult.ratios.sublist(i),
          );
          break;
        }
      }
    }

    final RenderNode? remainder = remainingTextLines != null
        ? (RenderRemainderRichTextLines(
            remainingTextLines: remainingTextLines,
            lineBreakMode: lineBreakMode,
            fontSize: fontSize,
            lineHeight: lineHeight,
          )..parent = parent)
        : null;

    return SliceLayoutResult(
      paintedPrimitives: placedLines,
      consumedSize: Size(maxWidth, currentY),
      remainder: remainder,
      metadata: metadataForThisSlice,
    );
  }
}

class RenderRemainderRichTextLines extends RenderNode with ContainerRenderNodeMixin, RenderSlice {
  final WrapResult remainingTextLines;
  final double fontSize;
  final double lineHeight;
  final LineBreakMode lineBreakMode;
  RenderRemainderRichTextLines({
    required this.lineBreakMode,
    required this.fontSize,
    required this.lineHeight,
    required this.remainingTextLines,
  });

  @override
  LayoutResult performLayout() {
    throw UnimplementedError();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    double currentY = 0;
    for (final child in children) {
      child.paint(context, offset + Offset(0, currentY));
      currentY += child.size.height;
    }
  }

  @override
  SliceLayoutResult layoutSlice(SliceLayoutContext context) {
    final List<PositionedPrimitive> placedLines = [];
    final List<MetadataRecord> metadataForThisSlice = [];
    double currentY = 0;
    double maxWidth = 0;
    WrapResult? newRemaining;

    final childLayoutContext = LayoutContext(
      pwContext: context.pwContext,
      constraints: context.constraints,
      metadata: context.metadata,
    );

    if (lineBreakMode == LineBreakMode.greedy) {
      final greedyResult = remainingTextLines as GreedyWrapResult;
      for (int i = 0; i < greedyResult.lines.length; i++) {
        final lineSpans = greedyResult.lines[i];

        double maxFontSizeInLine = 0.0;
        for (final span in lineSpans) {
          maxFontSizeInLine = max(maxFontSizeInLine, span.style.resolve().fontSize);
        }
        if (maxFontSizeInLine == 0) maxFontSizeInLine = fontSize;

        final dynamicLineHeightFont = lineSpans.first.style.resolve().font;
        final dynamicLineHeight =
            FontManager.getFont(dynamicLineHeightFont, context.pwContext).emptyLineHeight *
            maxFontSizeInLine *
            lineHeight;

        if (currentY + dynamicLineHeight <= context.availableHeight) {
          for (final span in lineSpans) {
            if (span.metadata != null) {
              metadataForThisSlice.addAll(span.metadata!);
            }
          }
          final lineNode = RenderRichTextLine(lineSpans, fixedHeight: dynamicLineHeight);
          lineNode.layout(childLayoutContext);
          placedLines.add(PositionedPrimitive(lineNode, Offset(0, currentY)));
          currentY += dynamicLineHeight;
          if (lineNode.size.width > maxWidth) maxWidth = lineNode.size.width;
        } else {
          newRemaining = GreedyWrapResult(greedyResult.lines.sublist(i));
          break;
        }
      }
    } else if (lineBreakMode == LineBreakMode.knuthPlass) {
      final kpWrapResult = remainingTextLines as KnuthPlassWrapResult;
      for (int i = 0; i < kpWrapResult.specifications.length; i++) {
        final lineSpecs = kpWrapResult.specifications[i];

        double maxFontSizeInLine = 0.0;
        for (final spec in lineSpecs) {
          if (spec is Box) {
            maxFontSizeInLine = max(maxFontSizeInLine, spec.style.fontSize);
          }
        }
        if (maxFontSizeInLine == 0.0) maxFontSizeInLine = fontSize;
        //TODO use largest font type instead
        final firstFontHeightFont = (lineSpecs.firstWhere((s) => s is Box) as Box).style.font;
        final firstFontHeight = FontManager.getFont(firstFontHeightFont, context.pwContext);

        final dynamicLineHeight = firstFontHeight.emptyLineHeight * maxFontSizeInLine * lineHeight;

        if (currentY + dynamicLineHeight <= context.availableHeight) {
          for (final spec in lineSpecs) {
            if (spec is Box && spec.sourceSpan?.metadata != null) {
              metadataForThisSlice.addAll(spec.sourceSpan!.metadata!);
            }
          }
          final lineNode = RenderKnuthPlassTextLine(
            line: lineSpecs,
            ratio: kpWrapResult.ratios[i],
            maxFontSizeInLine: maxFontSizeInLine,
            fixedHeight: dynamicLineHeight,
          );
          lineNode.layout(childLayoutContext);
          placedLines.add(PositionedPrimitive(lineNode, Offset(0, currentY)));
          currentY += dynamicLineHeight;
          if (lineNode.size.width > maxWidth) maxWidth = lineNode.size.width;
        } else {
          newRemaining = KnuthPlassWrapResult(
            specifications: kpWrapResult.specifications.sublist(i),
            ratios: kpWrapResult.ratios.sublist(i),
          );
          break;
        }
      }
    }

    final RenderNode? remainder = newRemaining != null
        ? (RenderRemainderRichTextLines(
            remainingTextLines: newRemaining,
            lineBreakMode: lineBreakMode,
            fontSize: fontSize,
            lineHeight: lineHeight,
          )..parent = parent)
        : null;

    return SliceLayoutResult(
      paintedPrimitives: placedLines,
      consumedSize: Size(maxWidth, currentY),
      remainder: remainder,
      metadata: metadataForThisSlice,
    );
  }
}

class RenderLineBreakConfiguration extends RenderNode with RenderObjectWithChildMixin, RenderSlice {
  final LineBreakSettings settings;
  RenderLineBreakConfiguration(this.settings);

  @override
  LayoutResult performLayout() {
    if (child == null) {
      return LayoutResult.zero;
    }
    final result = child!.layout(layoutContext!);
    size = result.size;
    return result;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    child?.paint(context, offset);
  }

  @override
  SliceLayoutResult layoutSlice(SliceLayoutContext context) {
    if (child == null) {
      return const SliceLayoutResult(paintedPrimitives: [], consumedSize: Size.zero);
    }
    if (child is! RenderSlice) {
      final layoutContext = LayoutContext(
        pwContext: context.pwContext,
        constraints: context.constraints,
        metadata: context.metadata,
      );
      final childResult = child!.layout(layoutContext);
      if (childResult.size.height <= context.availableHeight) {
        return SliceLayoutResult(
          paintedPrimitives: [PositionedPrimitive(this, Offset.zero)],
          consumedSize: childResult.size,
          remainder: null,
          metadata: childResult.metadata,
        );
      } else {
        return SliceLayoutResult(paintedPrimitives: const [], consumedSize: Size.zero, remainder: this);
      }
    }

    final childResult = (child as RenderSlice).layoutSlice(context);
    final RenderNode? finalRemainder = childResult.remainder != null
        ? (RenderLineBreakConfiguration(settings)
            ..child = childResult.remainder
            ..parent = this)
        : null;

    return SliceLayoutResult(
      paintedPrimitives: childResult.paintedPrimitives,
      consumedSize: childResult.consumedSize,
      remainder: finalRemainder,
      metadata: childResult.metadata,
    );
  }
}

class _StyledWord {
  final String text;
  final TextStyle style;
  final List<MetadataRecord>? metadata;
  _StyledWord(this.text, this.style, {this.metadata});
}

abstract class WrapResult {}

class GreedyWrapResult implements WrapResult {
  final List<List<TextSpan>> lines;
  GreedyWrapResult(this.lines);
}

class KnuthPlassWrapResult implements WrapResult {
  final List<List<Specification>> specifications;
  final List<double> ratios;

  KnuthPlassWrapResult({required this.specifications, required this.ratios});
}

class TextWrapper {
  static WrapResult wrap({
    required LineBreakMode mode,
    required List<TextSpan> spans,
    required double fontSize,
    required double maxWidth,
    required pw.Context pwContext,
  }) {
    switch (mode) {
      case LineBreakMode.greedy:
        return _richGreedyWrap(spans, maxWidth, pwContext);
      case LineBreakMode.knuthPlass:
        final paragraph = makeParagraph(pwContext, spans);
        final tolerances = [1.0, 2.0, 5.0, 10.0, 100.0, 10_000.0];
        for (final tolerance in tolerances) {
          try {
            final kp = knuthPlass(paragraph, maxWidth, pwContext: pwContext, tolerance: tolerance);
            return KnuthPlassWrapResult(specifications: kp.lines, ratios: kp.ratios);
          } catch (e) {
            if (tolerance == tolerances.last) {
              print("tolerance never found");
            }
          }
        }
        final kp = knuthPlass(paragraph, maxWidth, pwContext: pwContext, tolerance: 1000);
        return KnuthPlassWrapResult(specifications: kp.lines, ratios: kp.ratios);
    }
  }

  static GreedyWrapResult _richGreedyWrap(List<TextSpan> spans, double maxWidth, pw.Context pwContext) {
    if (spans.isEmpty) {
      return GreedyWrapResult([]);
    }

    final List<_StyledWord> styledWords = [];
    final wordRegex = RegExp(r'(\s+)|(\S+)');

    for (final span in spans) {
      final style = span.style;
      final padding = style.leftPadding ?? 0.0;

      if (padding > 0.0) {
        styledWords.add(_StyledWord('', TextStyle(leftPadding: padding), metadata: span.metadata));

        if (span.text.isNotEmpty) {
          final styleWithoutPadding = style.merge(const TextStyle(leftPadding: 0.0));
          for (final match in wordRegex.allMatches(span.text)) {
            styledWords.add(_StyledWord(match.group(0)!, styleWithoutPadding, metadata: span.metadata));
          }
        }
      } else {
        for (final match in wordRegex.allMatches(span.text)) {
          styledWords.add(_StyledWord(match.group(0)!, style, metadata: span.metadata));
        }
      }
    }

    if (styledWords.isEmpty) {
      return GreedyWrapResult([]);
    }

    final List<List<TextSpan>> resultLines = [];
    List<TextSpan> currentLineSpans = [];
    double currentLineWidth = 0.0;

    for (final word in styledWords) {
      final isSpace = word.text.trim().isEmpty;

      final resolvedStyle = word.style.resolve();
      final pdfFont = FontManager.getFont(resolvedStyle.font, pwContext);
      final wordWidth = (pdfFont.stringMetrics(word.text).width * resolvedStyle.fontSize) + resolvedStyle.leftPadding;
      if (wordWidth > maxWidth && !isSpace && currentLineSpans.isEmpty) {
        if (currentLineSpans.isNotEmpty) {
          resultLines.add(currentLineSpans);
          currentLineSpans = [];
          currentLineWidth = 0;
        }

        String currentPart = '';
        for (int i = 0; i < word.text.length; i++) {
          final char = word.text[i];
          final partWidth = pdfFont.stringMetrics(currentPart + char).width * resolvedStyle.fontSize;
          if (partWidth > maxWidth) {
            resultLines.add([TextSpan(currentPart, style: word.style, metadata: word.metadata)]);
            currentPart = char;
          } else {
            currentPart += char;
          }
        }

        currentLineSpans.add(TextSpan(currentPart, style: word.style, metadata: word.metadata));
        currentLineWidth = pdfFont.stringMetrics(currentPart).width * resolvedStyle.fontSize;
        continue;
      }

      if (currentLineWidth + wordWidth <= maxWidth) {
        currentLineSpans.add(TextSpan(word.text, style: word.style, metadata: word.metadata));
        currentLineWidth += wordWidth;
      } else {
        resultLines.add(currentLineSpans);

        final newText = word.text.trimLeft();
        final newResolvedStyle = word.style.resolve();
        final newPdfFont = FontManager.getFont(newResolvedStyle.font, pwContext);
        final newWidth =
            (newPdfFont.stringMetrics(newText).width * newResolvedStyle.fontSize) + newResolvedStyle.leftPadding;

        currentLineSpans = [TextSpan(newText, style: word.style, metadata: word.metadata)];
        currentLineWidth = newWidth;
      }
    }

    if (currentLineSpans.isNotEmpty) {
      resultLines.add(currentLineSpans);
    }

    return GreedyWrapResult(resultLines);
  }
}
