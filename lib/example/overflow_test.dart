import '../typesetting_prototype.dart';

void main() async {
  print('Generating PDF...');

  final myDocument = Document(
    pageMargin: const EdgeInsets.all(30),
    body: PageLayout(
      header: PageSection.fixed(height: 20, builder: (context) => Text('Header')),
      footer: PageSection.fixed(height: 20, builder: (context) => Text('Footer - Page ${context.formattedPageNumber}')),
      body: [
        const Text('This is the first page.'),
        const SizedBox(height: 20),
        const SizedBox(height: 800),
        const Text('This text should not appear.', fontSize: 24),
      ],
    ),
  );
  try {
    PdfGenerator.generatePdf(myDocument, "test_oversized_widget.pdf");
  } catch (e) {
    print('\n❌ PDF generation failed with an exception:');
    print(e);
  }
}
