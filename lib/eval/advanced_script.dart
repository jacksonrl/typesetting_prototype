import 'script_stdlib.dart';

ScriptDocument main() {
  final lipsum =
      'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.';

  return ScriptDocument(
    body: ScriptPageLayout(
      header: ScriptPageSection.fixed(
        height: 30,
        builder: (context) {
          return ScriptText('Advanced Script Header (Page ${context.formattedPageNumber})');
        },
      ),
      footer: ScriptPageSection.fixed(
        height: 20,
        builder: (context) => ScriptText('Footer From Script', font: ScriptFont.helvetica),
      ),
      footnoteBuilder: (items) {
        print("building footnotes");
        print(items.first.content);

        final List<ScriptWidget> children = [];
        for (final item in items) {
          children.add(ScriptText('${item.footnoteNumber}. ${item.content}', fontSize: 9));
        }

        return ScriptColumn(children: children);
      },
      body: [
        ScriptMetadataMarker(
          key: '__footnote',
          value: ScriptFootnoteLayoutInfo(content: "hello footnote", position: 0.0, number: 1),
          child: ScriptText('A manual footnote¹'),
        ),
        ScriptMetadataMarker(
          key: 'chapterTitle',
          value: 'Chapter 1: The Basics',
          child: ScriptText('A Title Wrapped in Metadata', fontSize: 18),
        ),
        ScriptSizedBox(height: 10),

        ScriptFormattedText(
          """
          This is a demonstration of the #bold[FormattedText] widget from a script.
          It can handle multiple paragraphs by looking for double newlines.

          This is the second paragraph. It will be indented because we set the #italic[paragraphIndent] property.
          Footnotes are also supported! #footnote[This is a scripted footnote.]
          """,
          fontSize: 12,
          newlinesForBreak: 2,
          paragraphIndent: 20,
          indentFirstParagraph: false,
        ),

        ScriptSizedBox(height: 20),
        ScriptResetPageNumber(style: ScriptPageNumberStyle.romanLower, startAt: 4),
        ScriptText('Page numbering has been reset to Roman numerals.'),
        ScriptSizedBox(height: 20),
        ScriptResetPageNumber(style: ScriptPageNumberStyle.arabic, startAt: 1),
        ScriptMetadataMarker(
          key: 'chapterTitle',
          value: 'Chapter 2: Columns',
          child: ScriptText('Multi-Column Layout', fontSize: 18),
        ),
        ScriptLineBreakConfiguration(
          mode: ScriptLineBreakMode.knuthPlass,
          child: ScriptMultiColumn(
            columnCount: 3,
            columnSpacing: 10,
            children: [
              for (int i = 0; i < 6; i++)
                ScriptPadding(padding: ScriptEdgeInsets.only(bottom: 5.0), child: ScriptText('Item $i. $lipsum')),
            ],
          ),
        ),
        ScriptSizedBox(height: 10),
        ScriptText('Back to single column flow.'),
      ],
    ),
  );
}
