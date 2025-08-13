import 'dart:convert';
import 'dart:math';

import 'package:typesetting_prototype/knuth/hyph_data.dart';
import 'package:typesetting_prototype/platform/file_provider_interface.dart';
import 'package:typesetting_prototype/typesetting_prototype.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class TrieNode {
  final Map<String, TrieNode> children = {};
  List<int>? values;
}

class KnuthLiangHyphenator {
  final TrieNode _root = TrieNode();
  final int leftMin = 2;
  final int rightMin = 2;

  KnuthLiangHyphenator._();

  factory KnuthLiangHyphenator.fromPatterns(String patterns) {
    final hyphenator = KnuthLiangHyphenator._();

    final lines = patterns.split('\n');
    for (final line in lines) {
      if (line.isEmpty || line.startsWith('%')) continue;
      hyphenator._insertPattern(line);
    }
    return hyphenator;
  }

  void _insertPattern(String pattern) {
    final List<String> chars = [];
    final List<int> values = [0];
    for (int i = 0; i < pattern.length; i++) {
      final char = pattern[i];
      if (int.tryParse(char) != null) {
        values.last = int.parse(char);
      } else {
        chars.add(char);
        values.add(0);
      }
    }
    TrieNode currentNode = _root;
    for (final char in chars) {
      currentNode = currentNode.children.putIfAbsent(char, () => TrieNode());
    }
    currentNode.values = values;
  }

  List<int> findBreakpoints(String word) {
    if (word.length <= (leftMin + rightMin)) {
      return [];
    }
    final lowerWord = word.toLowerCase();
    final processedWord = '.$lowerWord.';
    final points = List.filled(processedWord.length + 1, 0);

    for (int i = 0; i < processedWord.length; i++) {
      TrieNode currentNode = _root;
      for (int j = i; j < processedWord.length; j++) {
        final char = processedWord[j];
        if (!currentNode.children.containsKey(char)) break;
        currentNode = currentNode.children[char]!;
        if (currentNode.values != null) {
          for (int k = 0; k < currentNode.values!.length; k++) {
            points[i + k] = max(points[i + k], currentNode.values![k]);
          }
        }
      }
    }

    final List<int> breakPoints = [];
    for (int i = leftMin; i < word.length - rightMin; i++) {
      if (points[i + 1] % 2 != 0) {
        breakPoints.add(i);
      }
    }
    return breakPoints;
  }
}

class HyphenatorService {
  static KnuthLiangHyphenator? instance;

  static void initializeWithDefault() {
    instance ??= KnuthLiangHyphenator.fromPatterns(usEnglishHyphenationPatterns);
  }

  static Future<KnuthLiangHyphenator> loadFromFile(String path, FileProvider provider) async {
    final patternBytes = provider.load(path);
    final patternString = utf8.decode(patternBytes);
    final newInstance = KnuthLiangHyphenator.fromPatterns(patternString);
    instance = newInstance;
    return newInstance;
  }

  static KnuthLiangHyphenator get() {
    initializeWithDefault();
    return instance!;
  }
}

abstract class Specification {
  final double width;
  Specification(this.width);
  bool get isBox => this is Box;
  bool get isGlue => this is Glue;
  bool get isPenalty => this is Penalty;
}

class Box extends Specification {
  final String value;
  final ResolvedTextStyle style;
  final TextSpan? sourceSpan;

  Box(super.width, this.value, {required this.style, this.sourceSpan});
}

class Glue extends Specification {
  final double stretch;
  final double shrink;
  Glue(super.width, this.stretch, this.shrink);
  double rWidth(double ratio) => width + (ratio >= 0 ? ratio * stretch : ratio * shrink);
}

class Penalty extends Specification {
  final int penalty;
  final bool isHyphen;
  Penalty(super.width, this.penalty, {this.isHyphen = false});
}

List<Specification> makeParagraph(pw.Context pwContext, List<TextSpan> spans, {int hyphenPenalty = 50}) {
  final hyphenator = HyphenatorService.get();
  final List<Specification> paragraph = [];
  for (int spanIndex = 0; spanIndex < spans.length; spanIndex++) {
    final span = spans[spanIndex];
    final style = span.style.resolve();
    final font = FontManager.getFont(style.font, pwContext);

    if (style.leftPadding > 0) {
      paragraph.add(Box(style.leftPadding, '', style: style, sourceSpan: span));
    }

    final words = span.text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

    if (words.isEmpty) {
      continue;
    }

    for (int wordIndex = 0; wordIndex < words.length; wordIndex++) {
      final word = words[wordIndex];
      final breakpoints = hyphenator.findBreakpoints(word);

      int start = 0;
      for (final int bp in breakpoints) {
        final syllable = word.substring(start, bp + 1);
        final syllableWidth = font.stringMetrics(syllable).width * style.fontSize;
        paragraph.add(Box(syllableWidth, syllable, style: style, sourceSpan: span));
        paragraph.add(Penalty(0, hyphenPenalty, isHyphen: true));
        start = bp + 1;
      }

      if (start < word.length) {
        final lastSyllable = word.substring(start);
        final syllableWidth = font.stringMetrics(lastSyllable).width * style.fontSize;
        paragraph.add(Box(syllableWidth, lastSyllable, style: style, sourceSpan: span));
      }

      final bool isLastWordInSpan = wordIndex == words.length - 1;
      bool addSpace = false;

      if (!isLastWordInSpan) {
        addSpace = true;
      } else {
        final bool isLastSpanInParagraph = spanIndex == spans.length - 1;
        if (!isLastSpanInParagraph) {
          final nextSpan = spans[spanIndex + 1];
          if (span.text.trimRight().length < span.text.length ||
              nextSpan.text.trimLeft().length < nextSpan.text.length) {
            addSpace = true;
          }
        }
      }

      if (addSpace) {
        final spaceWidth = font.stringMetrics(' ').width * style.fontSize;
        paragraph.add(Glue(spaceWidth, spaceWidth * 0.5, spaceWidth / 3.0));
      }
    }
  }

  paragraph.add(Glue(0, 1e6, 0));
  paragraph.add(Penalty(0, -10000, isHyphen: false));
  return paragraph;
}

class DPResult {
  double demerits;
  int previousBreak;
  double ratio;
  DPResult({this.demerits = double.infinity, this.previousBreak = -1, this.ratio = 0.0});
}

({List<List<Specification>> lines, List<double> ratios}) knuthPlass(
  List<Specification> paragraph,
  double lineWidth, {

  required pw.Context pwContext,
  double tolerance = 1.0,
}) {
  final List<int> breakNodes = [0];
  for (int i = 0; i < paragraph.length; i++) {
    final spec = paragraph[i];
    if (spec is Penalty && spec.penalty < 10000) {
      breakNodes.add(i);
    } else if (spec.isGlue && i > 0 && paragraph[i - 1].isBox) {
      breakNodes.add(i);
    }
  }
  if (breakNodes.last != paragraph.length - 1) {
    breakNodes.add(paragraph.length - 1);
  }

  final dpTable = List.generate(breakNodes.length, (_) => DPResult());
  dpTable[0].demerits = 0;

  for (int i = 1; i < breakNodes.length; i++) {
    final currentBreakNode = breakNodes[i];
    for (int j = 0; j < i; j++) {
      final previousBreakNode = breakNodes[j];
      final lineStartIndex = (previousBreakNode == 0) ? 0 : previousBreakNode + 1;

      double idealWidth = 0;
      double stretch = 0;
      double shrink = 0;

      final breakSpec = paragraph[currentBreakNode];
      final contentEndIndex = (breakSpec.isGlue) ? currentBreakNode - 1 : currentBreakNode;

      for (int k = lineStartIndex; k <= contentEndIndex; k++) {
        final spec = paragraph[k];
        idealWidth += spec.width;
        if (spec is Glue) {
          stretch += spec.stretch;
          shrink += spec.shrink;
        }
      }

      if (breakSpec is Penalty && breakSpec.isHyphen) {
        if (currentBreakNode > 0 && paragraph[currentBreakNode - 1] is Box) {
          final prevBox = paragraph[currentBreakNode - 1] as Box;
          final prevBoxFont = FontManager.getFont(prevBox.style.font, pwContext);
          idealWidth += prevBoxFont.stringMetrics('-').width * prevBox.style.fontSize;
        }
      }

      double ratio = 0;
      if (idealWidth < lineWidth) {
        ratio = stretch > 0 ? (lineWidth - idealWidth) / stretch : 1e6;
      } else if (idealWidth > lineWidth) {
        ratio = shrink > 0 ? (lineWidth - idealWidth) / shrink : -1e6;
      }
      if (ratio < -1.0 || ratio > tolerance) continue;

      double badness;
      final isFinalBreak = (breakSpec is Penalty && breakSpec.penalty <= -10000);
      badness = isFinalBreak ? 0 : 100 * pow(ratio.abs(), 3).toDouble();

      final penaltyVal = (breakSpec is Penalty) ? breakSpec.penalty.toDouble() : 0.0;
      double demerits;
      if (penaltyVal >= 0) {
        demerits = pow(1 + badness + penaltyVal, 2).toDouble();
      } else if (isFinalBreak) {
        demerits = pow(1 + badness, 2).toDouble();
      } else {
        demerits = pow(1 + badness, 2) - pow(penaltyVal, 2).toDouble();
      }

      final totalDemerits = dpTable[j].demerits + demerits;
      if (totalDemerits < dpTable[i].demerits) {
        dpTable[i] = DPResult(demerits: totalDemerits, previousBreak: j, ratio: ratio);
      }
    }
  }

  final lastDPResult = dpTable.last;
  if (lastDPResult.demerits.isInfinite) {
    throw Exception("Could not find a feasible solution. Try a higher tolerance.");
  }

  final List<List<Specification>> lines = [];
  final List<double> ratios = [];
  int current = breakNodes.length - 1;
  while (current > 0) {
    final prev = dpTable[current].previousBreak;
    final startIndex = (breakNodes[prev] == 0) ? 0 : breakNodes[prev] + 1;
    final endIndex = breakNodes[current];
    lines.insert(0, paragraph.sublist(startIndex, endIndex + 1));
    ratios.insert(0, dpTable[current].ratio);
    current = prev;
  }
  return (lines: lines, ratios: ratios);
}

class FootnotePosition {
  double firstLineTopY;
  double firstLineBottomY;
  double lastLineTopY;
  double lastLineBottomY;

  FootnotePosition({
    required this.firstLineTopY,
    required this.firstLineBottomY,
    required this.lastLineTopY,
    required this.lastLineBottomY,
  });

  @override
  String toString() {
    if ((lastLineTopY - firstLineTopY).abs() < 0.01) {
      return 'Appears on a single line. Bounds: [Top: ${firstLineTopY.toStringAsFixed(2)}, Bottom: ${firstLineBottomY.toStringAsFixed(2)}]';
    }
    return 'Spans multiple lines.\n'
        '  - First line bounds: [Top: ${firstLineTopY.toStringAsFixed(2)}, Bottom: ${firstLineBottomY.toStringAsFixed(2)}]\n'
        '  - Last line bounds:  [Top: ${lastLineTopY.toStringAsFixed(2)}, Bottom: ${lastLineBottomY.toStringAsFixed(2)}]';
  }
}

Map<TextSpan, FootnotePosition> findFootnotePositions(
  List<List<Specification>> lines, {
  required double defaultLeading,
}) {
  final positions = <TextSpan, FootnotePosition>{};
  double accumulatedY = 0;

  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];

    double maxFontSizeInLine = 0;
    for (final spec in line) {
      if (spec is Box) {
        maxFontSizeInLine = max(maxFontSizeInLine, spec.style.fontSize);
      }
    }
    if (maxFontSizeInLine == 0) maxFontSizeInLine = TextStyle.normal.fontSize!;
    final double lineHeight = maxFontSizeInLine * defaultLeading;

    final currentTopY = accumulatedY;
    final currentBottomY = currentTopY + lineHeight;

    for (final spec in line) {
      if (spec is Box && spec.sourceSpan != null) {
        final span = spec.sourceSpan!;
        final bool isFootnote = span.metadata?.any((meta) => meta.key == '__footnote') ?? false;

        if (isFootnote) {
          if (!positions.containsKey(span)) {
            positions[span] = FootnotePosition(
              firstLineTopY: currentTopY,
              firstLineBottomY: currentBottomY,
              lastLineTopY: currentTopY,
              lastLineBottomY: currentBottomY,
            );
          } else {
            final position = positions[span]!;
            position.lastLineTopY = currentTopY;
            position.lastLineBottomY = currentBottomY;
          }
        }
      }
    }
    accumulatedY += lineHeight;
  }
  return positions;
}

Future<void> generatePdf({
  required List<List<Specification>> lines,
  required List<double> ratios,

  required double lineWidth,
  double defaultLeading = 1.2,
}) async {
  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      margin: pw.EdgeInsets.all(72.0),
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) {
        return pw.CustomPaint(
          size: PdfPoint(lineWidth, double.infinity),
          painter: (PdfGraphics canvas, PdfPoint size) {
            double currentY = size.y;
            for (int i = 0; i < lines.length; i++) {
              final line = lines[i];
              final ratio = ratios[i];
              double maxFontSizeInLine = 0;
              for (final spec in line) {
                if (spec is Box) {
                  maxFontSizeInLine = max(maxFontSizeInLine, spec.style.fontSize);
                }
              }
              if (maxFontSizeInLine == 0) {
                maxFontSizeInLine = TextStyle.normal.fontSize!;
              }

              final double lineHeight = maxFontSizeInLine * defaultLeading;
              currentY -= lineHeight;

              double currentX = 0;
              for (final spec in line) {
                if (spec is Box) {
                  final style = spec.style;
                  final yOffset = style.yOffsetFactor * style.fontSize;
                  final pdfFont = FontManager.getFont(style.font, context);
                  canvas.drawString(pdfFont, style.fontSize, spec.value, currentX, currentY + yOffset);
                  currentX += spec.width;
                } else if (spec is Glue) {
                  if (spec != line.last) {
                    final spaceWidth = (i == lines.length - 1) ? spec.width : spec.rWidth(ratio);
                    currentX += spaceWidth;
                  }
                } else if (spec is Penalty && spec.isHyphen && spec == line.last) {
                  final boxBefore = line.length > 1 ? line[line.length - 2] : null;
                  if (boxBefore is Box) {
                    final pdfFont = FontManager.getFont(boxBefore.style.font, context);
                    canvas.drawString(pdfFont, boxBefore.style.fontSize, '-', currentX, currentY);
                  }
                }
              }
            }
          },
        );
      },
    ),
  );
  PdfGenerator.generatePwPdf(doc, "knuth_plass_justified.pdf");
}

void main() async {
  final footnoteSpan = TextSpan(
    "However, this tends to be a misnomer, because printers have traditionally used justification to mean the process of taking an individual line of type and adjusting its spacing to produce a desired length.",
    metadata: [MetadataRecord(key: '__footnote', value: "footnote content")],
  );

  final spans = [
    TextSpan(
      "The line-breaking problem is informally called the problem of 'justification', since it is the 'J' of 'H & J' (hyphenation and justification) in today's commercial ",
      style: TextStyle.normal,
    ),
    TextSpan("composition", style: TextStyle.fromFont(fontSize: 12, font: Font.courierBold)),
    TextSpan(" and word-processing systems.", style: TextStyle.normal),
    TextSpan("1", style: TextStyle.superscript),
    TextSpan(" ", style: TextStyle.normal),
    footnoteSpan,
    TextSpan(
      " Even when text is being typeset with ragged right margins (therefore 'unjustified'), it needs to be broken into lines of approximately the same size.",
      style: TextStyle.normal,
    ),
  ];

  final double lineWidth = 250.0;
  const double defaultLeading = 1.2;

  try {
    final lowLevelDoc = PdfDocument();
    final pwContext = pw.Context(document: lowLevelDoc);

    print('Parsing paragraph from styled TextSpans...');
    final paragraph = makeParagraph(pwContext, spans, hyphenPenalty: 50);

    print('Calculating optimal breakpoints... (This may take a moment)');
    final result = knuthPlass(paragraph, lineWidth, pwContext: pwContext, tolerance: 2.5);

    print('Finding detailed footnote Y positions...');
    final footnotePositions = findFootnotePositions(result.lines, defaultLeading: defaultLeading);

    if (footnotePositions.isNotEmpty) {
      print('--- Footnote Report ---');
      footnotePositions.forEach((span, position) {
        final index = spans.indexOf(span);
        String label = 'Footnote';
        if (index > 0 && spans[index - 1].style == TextStyle.superscript) {
          label = 'Footnote "${spans[index - 1].text}"';
        }
        print('$label:\n$position');
      });
      print('-----------------------');
    }

    print('Generating PDF...');
    await generatePdf(lines: result.lines, ratios: result.ratios, lineWidth: lineWidth, defaultLeading: defaultLeading);
  } catch (e, st) {
    print('❌ An error occurred: $e\n$st');
  }
}
