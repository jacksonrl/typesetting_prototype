import '../typesetting_prototype.dart';

void main() async {
  print('Generating PDF...');

  final lipsum =
      'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.';

  final myDocument = Document(
    pageMargin: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
    tocBuilder: (registry) {
      return PageLayout(
        header: PageSection.fixed(height: 30, builder: (context) => Text('Table of Contents', fontSize: 24)),
        footer: PageSection.fixed(
          height: 20,
          builder: (context) => Text('Page ${context.formattedPageNumber}', fontSize: 10),
        ),
        body: [
          ResetPageNumber(style: PageNumberStyle.romanLower),
          FlowFill(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: 20),
                SizedBox(
                  width: 300,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final entry in registry.records)
                        if (entry.key == 'chapterTitle')
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                Text('${entry.value}'),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 5.0),
                                    child: Repeater('.'),
                                  ),
                                ),
                                Text(entry.formattedPageNumber),
                              ],
                            ),
                          ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    },
    body: PageLayout(
      header: PageSection.prototyped(
        prototype: const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: Text('Chapter Title Placeholder', fontSize: 10),
        ),
        builder: (context) {
          final titles = context.getMetadata<String>(key: 'chapterTitle').join(" - ");
          return Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(titles, fontSize: 10));
        },
      ),
      footer: PageSection.fixed(
        height: 20,
        builder: (context) =>
            Text('Page ${context.formattedPageNumber} of ${context.formattedTotalPages}', fontSize: 10),
      ),
      footnoteBuilder: (List<FootnoteItem> footnoteItems) {
        return LineBreakConfiguration(
          mode: LineBreakMode.knuthPlass,
          child: DecoratedBox(
            decoration: BoxDecoration(border: Border(top: BorderSide(width: 0.5))),
            child: Column(
              children: List.generate(
                footnoteItems.length,
                (int i) => RichText(
                  lineHeight: 1.1,
                  fontSize: 10,
                  children: [
                    TextSpan(
                      '${footnoteItems[i].footnoteNumber}. ${footnoteItems[i].content}',
                      style: TextStyle.fromFont(fontSize: 9, font: Font.courier),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      body: [
        MetadataMarker(
          key: '__footnote',
          value: FootnoteLayoutInfo(content: "hello footnote", position: 0.0, number: 1),
          child: const Text('A manual footnote¹'),
        ),
        LineBreakConfiguration(
          mode: LineBreakMode.knuthPlass,
          child: FormattedText(
            'This is a demonstration of the new footnote syntax.#footnote[This is the first footnote. It is automatically numbered and placed at the bottom of the page.] It makes adding references much easier. Here is a second reference.#footnote[This is the second footnote, showing that multiple footnotes on the same page are handled correctly.]',
          ),
        ),
        Image.file("C:/Users/jackson/Downloads/Stanford_Bunny.png", height: 50),
        LineBreakConfiguration(
          mode: LineBreakMode.knuthPlass,
          child: FormattedText(
            newlinesForBreak: 2,
            paragraphIndent: 20,
            """
            Here is some text with #bold[special formatting] specified via a markup syntax. We can wrap this whole block in a multi column layout. #footnote[And footnotes still work!]
            
            
            Multiple paragraphs are also supported.
            """,
            //builder: (paragraphs) => MultiColumnFlow(children: paragraphs),
          ),
        ),
        ResetPageNumber(style: PageNumberStyle.arabic, startAt: 1),
        MetadataMarker(
          key: 'chapterTitle',
          value: 'Chapter 1: The Beginning',
          child: LineBreakConfiguration(
            mode: LineBreakMode.knuthPlass,
            child: RichText(
              children: [
                TextSpan('Start of the Document', style: TextStyle(fontSize: 18, decoration: TextDecoration.underline)),
              ],
            ),
          ),
        ),
        LineBreakConfiguration(
          mode: LineBreakMode.knuthPlass,
          child: MultiColumn(
            columnCount: 3,
            columnSpacing: 10,
            children: [Text('This is a small, balanced 3-column section. $lipsum')],
          ),
        ),
        const SizedBox(height: 10),
        const Text("This text appears after the 3-column block, demonstrating that the flow has resumed."),
        const SizedBox(height: 10),
        MetadataMarker(
          key: 'chapterTitle',
          value: 'Chapter 2: Multi-Column Flow',
          child: const Text('Multi-Column Flow', fontSize: 18),
        ),
        LineBreakConfiguration(
          mode: LineBreakMode.knuthPlass,
          child: MultiColumnFlow(
            columnCount: 2,
            columnSpacing: 15,
            children: [
              for (int i = 1; i <= 20; i++)
                Padding(padding: const EdgeInsets.symmetric(vertical: 2.0), child: Text('List item #$i. $lipsum')),
            ],
          ),
        ),
        SizedBox(height: 10),
        Text("Returning to Single-Column Flow", fontSize: 20),
        SizedBox(height: 10),
        LineBreakConfiguration(
          mode: LineBreakMode.knuthPlass,
          child: Text(List.generate(5, (int index) => lipsum).join(), font: Font.times),
        ),
        SizedBox(height: 20),
        KeepTogether(
          first: Column(
            children: [
              MetadataMarker(
                key: 'chapterTitle',
                value: 'Chapter 3: Synchronized Columns',
                child: const Text('Synchronized Columns', fontSize: 18),
              ),
              SizedBox(height: 10),
            ],
          ),
          second: LineBreakConfiguration(
            mode: LineBreakMode.knuthPlass,
            child: SyncedColumns(
              topColumnCount: 2,
              bottomColumnCount: 3,
              spacing: 20,
              topChildren: [
                for (int i = 1; i <= 15; i++)
                  Text(
                    'Synced Top Item #$i. This is the top content which is laid out in two columns. It should stay with its corresponding bottom item. $lipsum',
                  ),
              ],
              bottomChildren: [
                for (int i = 1; i <= 15; i++)
                  Text(
                    'Synced Bottom Item #$i. This content is in three columns. This is a shorter piece of text to demonstrate different layouts. The key is that it moves to the next page at the same time as Top Item #$i.',
                  ),
              ],
            ),
          ),
        ),
        LineBreakConfiguration(
          mode: LineBreakMode.knuthPlass,
          child: FormattedText(
            'This is a demonstration of the new footnote syntax.#footnote[This is the first footnote. It is automatically numbered and placed at the bottom of the page.] It makes adding references much easier. Here is a second reference.#footnote[This is the second footnote, showing that multiple footnotes on the same page are handled correctly.]',
          ),
        ),
        LineBreakConfiguration(
          mode: LineBreakMode.knuthPlass,
          child: FormattedText('This is a demonstration of the new #bold[bold text] and #italic[italic] syntax.'),
        ),
        SizedBox(height: 10),
        Text("Document End.", fontSize: 20),
        FlowFill(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [Text("Some Centered Text")],
          ),
        ),
      ],
    ),
  );

  PdfGenerator.generatePdf(myDocument, "prototype.pdf");
  print('Successfully generated prototype.pdf');
}
