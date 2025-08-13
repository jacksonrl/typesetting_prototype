import 'package:typesetting_prototype/typesetting_prototype.dart';

void main() async {
  print("generating pdf");
  final lipsum =
      'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.';

  final myDocument = Document(
    body: PageLayout(
      header: PageSection.fixed(
        height: 30,
        builder: (context) {
          return Text('Advanced  Header (Page ${context.formattedPageNumber})');
        },
      ),
      footer: PageSection.fixed(height: 20, builder: (context) => Text('Footer From ', font: Font.helvetica)),
      footnoteBuilder: (items) {
        print("building footnotes");
        print(items.first.content);

        final List<Widget> children = [];
        for (final item in items) {
          children.add(Text('${item.footnoteNumber}. ${item.content}', fontSize: 9));
        }
        return Column(children: children);
      },
      body: [
        MetadataMarker(
          key: '__footnote',
          value: FootnoteLayoutInfo(content: "hello footnote", position: 0.0, number: 1),
          child: Text('A manual footnote¹'),
        ),
        MetadataMarker(
          key: 'chapterTitle',
          value: 'Chapter 1: The Basics',
          child: Text('A Title Wrapped in Metadata', fontSize: 18),
        ),
        SizedBox(height: 10),

        FormattedText(
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

        SizedBox(height: 20),
        ResetPageNumber(style: PageNumberStyle.romanLower, startAt: 4),
        Text('Page numbering has been reset to Roman numerals.'),
        SizedBox(height: 20),
        ResetPageNumber(style: PageNumberStyle.arabic, startAt: 1),
        MetadataMarker(
          key: 'chapterTitle',
          value: 'Chapter 2: Columns',
          child: Text('Multi-Column Layout', fontSize: 18),
        ),
        LineBreakConfiguration(
          mode: LineBreakMode.knuthPlass,
          child: MultiColumn(
            columnCount: 3,
            columnSpacing: 10,
            children: [
              for (int i = 0; i < 6; i++)
                Padding(padding: EdgeInsets.only(bottom: 5.0), child: Text('Item $i. $lipsum')),
            ],
          ),
        ),
        SizedBox(height: 10),
        Text('Back to single column flow.'),
      ],
    ),
  );
  PdfGenerator.generatePdf(myDocument, "test111.pdf");
}
