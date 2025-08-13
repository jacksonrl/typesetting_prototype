function defineDocument() {
  const lipsum =
    "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.";

  const textBlock = (text) =>
    Padding({
      padding: EdgeInsets.symmetric({ vertical: 4 }),
      child: Text(text),
    });

  return Document({
    pageMargin: EdgeInsets.all(40),
    body: PageLayout({
      header: PageSection.fixed({
        height: 25,
        builder: (context) => {
          const title = `JS Widget Showcase`; // Placeholder
          return Row({
            children: [
              Text(title, { fontSize: 10 }),
              Expanded({ child: SizedBox({}) }),
              Text(`Page ${context.formattedPageNumber}`, { fontSize: 10 }),
            ],
          });
        },
      }),
      footer: null,
      body: [
        Flow({
          children: [
            KeepTogether({
              first: Text("Section 1: Decorations & Layout", { fontSize: 18 }),
              second: DecoratedBox({
                decoration: BoxDecoration({
                  border: Border.all({ width: 0.5 }),
                }),
                child: Padding({
                  padding: EdgeInsets.all(10),
                  child: Column({
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "This Column is inside a DecoratedBox, which draws a border around it."
                      ),
                      SizedBox({ height: 5 }),
                      Row({
                        children: [
                          Text("A dotted line: "),
                          Expanded({ child: Repeater(" .") }),
                        ],
                      }),
                    ],
                  }),
                }),
              }),
            }),

            SizedBox({ height: 20 }),

            KeepTogether({
              first: Text("Section 2: Multi-Column Flow", { fontSize: 18 }),
              second: MultiColumnFlow({
                columnCount: 2,
                columnSpacing: 15,
                children: [
                  textBlock(
                    `This content is in a MultiColumnFlow. It will automatically fill the first column on this page, then flow into the second column.`
                  ),
                  textBlock(lipsum),
                  textBlock(
                    `If there is more content than can fit on this page, it will continue in columns on the next page. This is different from the standard MultiColumn widget, which tries to balance all its content into a single block.`
                  ),
                  textBlock(lipsum),
                  textBlock(lipsum),
                ],
              }),
            }),

            SizedBox({ height: 10 }),
            Text("This text appears after the multi-column flow."),
            SizedBox({ height: 20 }),

            KeepTogether({
              first: Text("Section 3: Synced Columns (Dictionary Example)", {
                fontSize: 18,
              }),
              second: SyncedColumns({
                topColumnCount: 1,
                bottomColumnCount: 2,
                bottomColumnSpacing: 10,
                spacing: 15,
                topChildren: [
                  textBlock(
                    "English Phrase 1: The quick brown fox jumps over the lazy dog."
                  ),
                  textBlock(
                    "English Phrase 2: She sells seashells by the seashore."
                  ),
                  textBlock(
                    "English Phrase 3: A journey of a thousand miles begins with a single step."
                  ),
                ],
                bottomChildren: [
                  textBlock(
                    "Translation 1: This is where the translation for the first phrase would go, laid out in its own column structure."
                  ),
                  textBlock(
                    "Translation 2: And the translation for the second phrase appears here, aligned with its source."
                  ),
                  textBlock(
                    "Translation 3: This layout is useful for bilingual documents or technical manuals where descriptions must stay with their corresponding images or text."
                  ),
                ],
              }),
            }),

            FlowFill({
              child: Column({
                mainAxisAlignment: "center",
                crossAxisAlignment: "center",
                children: [Text("--- End of Document ---", { fontSize: 16 })],
              }),
            }),
          ],
        }),
      ],
    }),
  });
}
