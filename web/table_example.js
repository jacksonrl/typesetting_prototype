function defineDocument() {
  return Document({
    pageMargin: EdgeInsets.all(40),
    body: PageLayout({
      header: PageSection.fixed({
        height: 30,
        builder: (context) =>
          Align({
            alignment: Alignment.centerLeft,
            child: Text("ACME Inc. - Product Catalog", { fontSize: 14 }),
          }),
      }),
      footer: PageSection.fixed({
        height: 20,
        builder: (context) =>
          Align({
            alignment: Alignment.centerRight,
            child: Text(`Page ${context.formattedPageNumber}`, {
              fontSize: 10,
            }),
          }),
      }),
      body: [
        Text("Product Catalog", { fontSize: 24 }),
        SizedBox({ height: 15 }),
        Text(
          "This document demonstrates the Table widget, including column widths, spanning, and automatic pagination."
        ),
        SizedBox({ height: 20 }),
        Table({
          columnWidths: {
            0: IntrinsicColumnWidth(),
            1: FlexColumnWidth(2),
            2: FlexColumnWidth(3),
            3: FixedColumnWidth(60),
            4: IntrinsicColumnWidth(),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.top,
          children: [
            TableRow({
              children: [
                buildHeaderCell("ID"),
                buildHeaderCell("Product Name"),
                buildHeaderCell("Description"),
                buildHeaderCell("Price"),
                buildHeaderCell("Status"),
              ],
            }),
            TableRow({
              children: [
                TableCell({
                  rowSpan: 2,
                  verticalAlignment: TableCellVerticalAlignment.middle,
                  child: Align({
                    alignment: Alignment.center,
                    child: Text("SPECIALS"),
                  }),
                }),
                buildContentCell(products[0].name),
                buildContentCell(products[0].description),
                buildPriceCell(products[0].price),
                buildStockCell(products[0].inStock),
              ],
            }),
            TableRow({
              children: [
                buildContentCell(products[1].name),
                buildContentCell(products[1].description),
                buildPriceCell(products[1].price),
                buildStockCell(products[1].inStock),
              ],
            }),
            ...products.slice(2).map((product) =>
              TableRow({
                children: [
                  buildContentCell(product.id.toString()),
                  buildContentCell(product.name),
                  buildContentCell(product.description, {
                    verticalAlignment: TableCellVerticalAlignment.bottom,
                  }),
                  buildPriceCell(product.price),
                  buildStockCell(product.inStock),
                ],
              })
            ),
            TableRow({
              children: [
                TableCell({
                  colSpan: 4,
                  child: Align({
                    alignment: Alignment.centerRight,
                    child: Padding({
                      padding: EdgeInsets.all(4),
                      child: Text("Grand Total"),
                    }),
                  }),
                }),
                buildPriceCell(
                  products
                    .reduce((sum, p) => sum + parseFloat(p.price), 0)
                    .toFixed(2)
                ),
              ],
            }),
          ],
        }),
        SizedBox({ height: 20 }),
        Text("This text appears after the table."),
      ],
    }),
  });
}

const products = Array.from({ length: 30 }, (_, i) => ({
  id: 1000 + i,
  name: `Product #${i + 1}`,
  description: `This is a detailed description for product number ${
    i + 1
  }. It might be quite long, causing the text to wrap within the cell.`,
  price: (19.99 + i * 5.5).toFixed(2),
  inStock: i % 4 !== 0,
}));

const buildHeaderCell = (text) =>
  TableCell({
    child: Padding({
      padding: EdgeInsets.all(6),
      child: Text(text, { fontSize: 10 }),
    }),
  });

const buildContentCell = (text, options = {}) =>
  TableCell({
    child: Padding({
      padding: EdgeInsets.all(4),
      child: Text(text, { fontSize: 9 }),
    }),
    ...options,
  });

const buildPriceCell = (price) =>
  TableCell({
    verticalAlignment: TableCellVerticalAlignment.middle,
    child: Align({
      alignment: Alignment.centerRight,
      child: Padding({
        padding: EdgeInsets.all(4),
        child: Text(`$${price}`, { fontSize: 9 }),
      }),
    }),
  });

const buildStockCell = (inStock) =>
  TableCell({
    verticalAlignment: TableCellVerticalAlignment.middle,
    child: Padding({
      padding: EdgeInsets.all(4),
      child: Text(inStock ? "In Stock" : "Out of Stock", {
        style: TextStyle({
          textColor: inStock ? Color.green : Color.red,
          fontSize: 8,
        }),
      }),
    }),
  });
