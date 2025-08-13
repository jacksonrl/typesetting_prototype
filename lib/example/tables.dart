import '../typesetting_prototype.dart';

class _Product {
  final int id;
  final String name;
  final String description;
  final double price;
  final bool inStock;
  final String category;

  const _Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.inStock,
    required this.category,
  });
}

final List<_Product> _products = List.generate(30, (i) {
  return _Product(
    id: 1000 + i,
    name: 'Product #${i + 1}',
    description:
        'This is a detailed description for product number ${i + 1}. It might be quite long, causing the text to wrap within the cell, which demonstrates how the table handles varying content heights.',
    price: (19.99 + i * 5.5),
    inStock: i % 4 != 0,
    category: i < 15 ? 'Gadgets' : 'Accessories',
  );
});

void main() async {
  print('🚀 Generating Table Demonstration PDF...');

  final myDocument = Document(
    pageMargin: const EdgeInsets.all(40),
    body: PageLayout(
      header: PageSection.fixed(
        height: 30,
        builder: (context) =>
            Align(alignment: Alignment.centerLeft, child: Text('ACME Inc. - Product Catalog', fontSize: 14)),
      ),

      footer: PageSection.fixed(
        height: 20,
        builder: (context) => Align(
          alignment: Alignment.centerRight,
          child: Text('Page ${context.formattedPageNumber} of ${context.formattedTotalPages}', fontSize: 10),
        ),
      ),

      body: [
        Text('Product Catalog', fontSize: 24),
        SizedBox(height: 15),
        Text(
          'This document demonstrates the capabilities of the Table widget, '
          'including various column widths, row/column spanning, vertical '
          'alignment, and automatic pagination for long tables.',
        ),
        SizedBox(height: 20),

        Table(
          columnWidths: const {
            0: IntrinsicColumnWidth(),
            1: FlexColumnWidth(2),
            2: FlexColumnWidth(3),
            3: FixedColumnWidth(60),
            4: IntrinsicColumnWidth(),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.top,
          children: [
            TableRow(
              children: [
                _buildHeaderCell('ID'),
                _buildHeaderCell('Product Name'),
                _buildHeaderCell('Description'),
                _buildHeaderCell('Price'),
                _buildHeaderCell('Status'),
              ],
            ),

            TableRow(
              children: [
                TableCell(
                  rowSpan: 2,
                  verticalAlignment: TableCellVerticalAlignment.fill,
                  child: DecoratedBox(
                    decoration: BoxDecoration(border: Border.all(color: Color.black)),

                    child: Align(alignment: Alignment.center, child: Text('SPECIALS', fontSize: 10)),
                  ),
                ),
                _buildContentCell(_products[0].name),
                _buildContentCell(_products[0].description),
                _buildPriceCell(_products[0].price),
                _buildStockCell(_products[0].inStock),
              ],
            ),
            TableRow(
              children: [
                _buildContentCell(_products[1].name),
                _buildContentCell(_products[1].description),
                _buildPriceCell(_products[1].price),
                _buildStockCell(_products[1].inStock),
              ],
            ),

            for (int i = 2; i < _products.length; i++)
              TableRow(
                children: [
                  _buildContentCell(_products[i].id.toString()),

                  TableCell(
                    verticalAlignment: TableCellVerticalAlignment.middle,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_products[i].name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text('Category: ${_products[i].category}', fontSize: 8),
                        ],
                      ),
                    ),
                  ),
                  _buildContentCell(_products[i].description, alignment: TableCellVerticalAlignment.bottom),
                  _buildPriceCell(_products[i].price),
                  _buildStockCell(_products[i].inStock),
                ],
              ),

            TableRow(
              children: [
                TableCell(
                  colSpan: 4,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text('Grand Total', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                TableCell(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
                    child: Text(
                      '\$${_products.fold<double>(0, (sum, p) => sum + p.price).toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),

        SizedBox(height: 20),
        Text('This text appears after the table, confirming that the document flow has resumed normally.'),
      ],
    ),
  );

  await PdfGenerator.generatePdf(myDocument, "table_demonstration.pdf");
  print('Successfully generated table_demonstration.pdf');
}

TableCell _buildHeaderCell(String text) {
  return TableCell(
    child: Padding(
      padding: const EdgeInsets.all(6),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
    ),
  );
}

TableCell _buildContentCell(String text, {TableCellVerticalAlignment alignment = TableCellVerticalAlignment.top}) {
  return TableCell(
    verticalAlignment: alignment,
    child: Padding(padding: const EdgeInsets.all(4), child: Text(text, fontSize: 9, lineHeight: 1.1)),
  );
}

TableCell _buildPriceCell(double price) {
  return TableCell(
    verticalAlignment: TableCellVerticalAlignment.middle,
    child: Padding(
      padding: const EdgeInsets.all(4),
      child: Align(alignment: Alignment.centerRight, child: Text('\$${price.toStringAsFixed(2)}', fontSize: 9)),
    ),
  );
}

TableCell _buildStockCell(bool inStock) {
  return TableCell(
    verticalAlignment: TableCellVerticalAlignment.middle,
    child: Padding(
      padding: const EdgeInsets.all(4),
      child: Text(
        inStock ? 'In Stock' : 'Out of Stock',
        fontSize: 9,
        style: TextStyle(textColor: inStock ? Color.fromHex('#008800') : Color.fromHex('#DD0000')),
      ),
    ),
  );
}
