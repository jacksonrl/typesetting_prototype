import 'package:typesetting_prototype/typesetting_prototype.dart';

void main() async {
  print('Generating PDF...');

  final doc = Document(
    pageMargin: EdgeInsets.all(40),
    body: PageLayout(
      footnoteBuilder: (List<FootnoteItem> items) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items
            .map(
              (item) => Padding(
                padding: EdgeInsets.only(bottom: 2),
                child: Text('${item.footnoteNumber}. ${item.content}', fontSize: 9),
              ),
            )
            .toList(),
      ),
      body: [
        Flow(
          children: [
            Row(
              children: [
                Text("You can also create footnote markers manually. See here:"),
                SizedBox(width: 2),
                MetadataMarker(
                  key: '__footnote',
                  value: FootnoteLayoutInfo(
                    content:
                        "This is a manually-defined footnote. It is correctly numbered in sequence with the automatic ones.",
                    position: 0,
                    number: 3,
                  ),
                  child: Text("3", fontSize: 8),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  );

  PdfGenerator.generatePdf(doc, "footnotetest.pdf");
  print('Successfully generated footnotetest.pdf');
}
