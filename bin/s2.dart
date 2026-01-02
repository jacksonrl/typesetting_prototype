import 'package:typesetting_prototype/typesetting_prototype.dart';

void main() async {
  print("Generating report.pdf...");

  final script = '''
    #set text(size: 10, weight: "normal")
    #set padding(all: 5)

    #let reportTitle = 'Inventory Report'
    #let generatedDate = '2023-10-27'

    #let inventory = [
      { name: "Widget A", count: 50, price: 10.5, tags: ["Sale", "New"] },
      { name: "Widget B", count: 0,  price: 22.0, tags: [] },
      { name: "Widget C", count: 5,  price: 5.0,  tags: ["Clearance"] }
    ]

    #let header = (text) => (
      #set text(size: 18, weight: "bold")
      Text(text)
      SizedBox(height: 10)
      Underline(child: SizedBox(width: 500, height: 1))
      SizedBox(height: 10)
    )

    #header(reportTitle)

    #Text("Date: " + generatedDate)
    #SizedBox(height: 20)

    #Text("Item List:", size: 14, weight: "bold")
    #SizedBox(height: 10)

    #for item, index in inventory (
      #let isOutOfStock = item.count == 0
      #let statusColor = isOutOfStock ? Color.red : Color.black
      #let stockStatus = isOutOfStock ? "Out of Stock" : "In Stock (" + item.count + ")"
      
      DecoratedBox(
        borderWidth: 0.5,
        borderColor: statusColor,
        
        Padding(
          all: 8,
          
          Row(children: [
            SizedBox(width: 20, child: Text(index + 1 + ".")),
            Expanded(flex: 2, child: Column([
              Text(item.name, weight: "bold"),
              Text(stockStatus, size: 8, textColor: statusColor)
            ])),
            Expanded(flex: 1, child: Text("\$" + item.price)),
            Expanded(flex: 1, child: 
              if (item.tags.length > 0) (
                 Row(children: [
                    for tag in item.tags (
                       DecoratedBox(
                         borderWidth: 1,
                         Padding(all: 2, Text(tag, size: 6))
                       )
                       SizedBox(width: 2)
                    )
                 ])
              ) else (
                 Text("-")
              )
            )
          ])
        )
      )
      SizedBox(height: 5)
    )

    #SizedBox(height: 20)

    #Text("Scoping Test - Base font size is 10")

    #{
      #set text(size: 20)
      #set padding(left: 50)
      
      Padding(
        Text("Inside block - Scoped font size is 20")
      )
    }

    #Text("Outside block - Font size is 10 again")

    #SizedBox(height: 20)

    #let stats = {
      Electronics: 150,
      Furniture: 20,
      Stationery: 500
    }

    #for category, count in stats (
      Row(
        SizedBox(width: 100, child: Text(category))
        Text(count)
        if (count < 50) (
          Padding(left: 10, Text("LOW STOCK WARNING", textColor: Color.red, weight: "bold"))
        )
      )
    )

    #SizedBox(height: 20)
    #Text("Pagination Test (0..5):")

    #Row(
      for i in 0..5 (
        Padding(all: 5, Text("[" + i + "]"))
      )
    )
    
    #SizedBox(height: 10)
    #Text("Count to 5 sugar:")

    #Row(
      for i in 5 (
         Padding(all: 5, Text(i))
      )
    )
  ''';

  final doc = Document(
    body: PageLayout(
      body: [
        FormattedText(script, fontSize: 12),
      ],
    ),
  );

  await PdfGenerator.generatePdf(doc, 'report.pdf');
  print("Done.");
}