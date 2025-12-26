import 'package:typesetting_prototype/typesetting_prototype.dart';

void main() async {
  final doc = Document(
    debug: true,
    body: PageLayout(
      header: PageSection.fixed(
        height: 25,
        builder: (context) {
          // In Dart, we use the method on the context object directly
          final titles = context.getMetadata<String>(key: "chapterTitle");
          final title = titles.isNotEmpty ? titles.first : "Dart Native Showcase";

          return DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(width: 0.5)),
            ),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                children: [
                  Text(title, fontSize: 9),
                  const Expanded(child: SizedBox.shrink()),
                  Text('Page ${context.formattedPageNumber}', fontSize: 9),
                ],
              ),
            ),
          );
        },
      ),

      footnoteBuilder: (items) {
        return DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(width: 0.5)),
          ),
          child: Padding(
            padding: const EdgeInsets.only(top: 5, left: 10, right: 10),
            child: Column(
              children: items.map((item) =>
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text('${item.footnoteNumber}. ${item.content}', fontSize: 9),
                )
              ).toList(),
            ),
          ),
        );
      },

      body: [
        const Flow(
          children: [
            SizedBox(height: 10),
            MetadataMarker(
              key: "chapterTitle",
              value: "Chapter 1: Automatic Footnotes",
              child: Text("Testing Metadata and Footnotes", fontSize: 22),
            ),

            SizedBox(height: 15),

            FormattedText(
              "The line-breaking problem is informally called the problem of 'justification', since it is the 'J' of 'H & J' (hyphenation and justification) in today's word-processing systems.#footnote[This is the first footnote. It is automatically numbered and placed at the bottom of the page.] Even when text is being typeset with ragged right margins, it needs to be broken into lines of approximately the same size.#footnote[This is the second footnote, demonstrating that multiple footnotes on the same page are handled correctly.]"
            ),

            SizedBox(height: 25),

            MetadataMarker(
              key: "chapterTitle",
              value: "Chapter 2: Manual Footnotes",
              child: Underline(
                child: Text("Manual Footnote Creation", fontSize: 18),
              ),
            ),

            SizedBox(height: 10),

            Row(
              children: [
                Text("This is a manually created footnote marker"),
                MetadataMarker(
                  key: "__footnote",
                  // Note: In Dart we use a specific class for the value
                  value: FootnoteLayoutInfo(
                    content: "This is a manually-defined footnote's text. It will be auto-numbered correctly after the others.",
                    number: 0, // This gets overwritten by the layout engine
                    position: 0,
                  ),
                  child: Text("3", fontSize: 8, style: TextStyle.superscript),
                ),
              ],
            ),

            FlowFill(
              child: SizedBox(height: 0),
            ),

            MetadataMarker(
              key: "chapterTitle",
              value: "Chapter 3: After the Page Break",
              child: Text(
                "This text appears on the next page, showing the running header has updated.",
                fontSize: 14
              ),
            ),
          ],
        ),
      ],
    ),
  );

  // This calls the native saver (dart:io)
  // Pass debug: true to see your tree dump in the terminal
  await PdfGenerator.generatePdf(doc, 'debug_output.pdf'); 
}