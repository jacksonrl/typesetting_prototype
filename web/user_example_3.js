function defineDocument() {
  const lipsum =
    "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.";

  const textBlock = (text, options = {}) =>
    Padding({
      padding: EdgeInsets.symmetric({ vertical: 4 }),
      child: Text(text, options),
    });

  return Document({
    pageMargin: EdgeInsets.all(40),
    tocBuilder: (registry) => {
      const chapterRecords = registry.records.filter(
        (record) => record.key === "chapterTitle"
      );
      const tocEntries = chapterRecords.map((record) =>
        Padding({
          padding: EdgeInsets.symmetric({ vertical: 2 }),
          child: Row({
            children: [
              Text(record.value, { fontSize: 12 }),
              Expanded({
                child: Padding({
                  padding: EdgeInsets.symmetric({ horizontal: 5 }),
                  child: Repeater(" ."),
                }),
              }),
              Text(record.formattedPageNumber, { fontSize: 12 }),
            ],
          }),
        })
      );
      return PageLayout({
        footer: PageSection.fixed({
          height: 20,
          builder: (context) =>
            Row({
              children: [
                Expanded({ child: SizedBox({}) }),
                Text(`Page ${context.formattedPageNumber}`, {
                  fontSize: 10,
                }),
              ],
            }),
        }),
        body: [
          ResetPageNumber({ style: "romanLower" }),
          FlowFill({
            child: Column({
              mainAxisAlignment: "center",
              crossAxisAlignment: "center",
              children: [
                Text("Table of Contents", {
                  fontSize: 20,
                  fontWeight: "bold",
                }),
                SizedBox({ height: 20 }),
                SizedBox({
                  width: 350,
                  child: Column({
                    crossAxisAlignment: "stretch",
                    children: tocEntries,
                  }),
                }),
              ],
            }),
          }),
        ],
      });
    },
    body: PageLayout({
      header: PageSection.fixed({
        height: 30,
        builder: (context) => {
          const titles = getMetadata(context, "chapterTitle");
          const title = titles.length > 0 ? titles[0] : "JS Widget Showcase";

          return DecoratedBox({
            decoration: BoxDecoration({
              border: Border({
                bottom: BorderSide({ width: 0.5, color: Color.black }),
              }),
            }),
            child: Padding({
              padding: EdgeInsets.only({ bottom: 5 }),
              child: Row({
                children: [
                  Text(title, { fontSize: 10, color: Color.black }),
                  Expanded({ child: SizedBox({}) }),
                  Text(`Page ${context.formattedPageNumber}`, {
                    fontSize: 10,
                    color: Color.black,
                  }),
                ],
              }),
            }),
          });
        },
      }),
      footnoteBuilder: (items) => {
        return DecoratedBox({
          decoration: BoxDecoration({
            border: Border({
              top: BorderSide({ width: 0.5, color: Color.black }),
            }),
          }),
          child: Padding({
            padding: EdgeInsets.only({ top: 5, left: 10, right: 10 }),
            child: Column({
              crossAxisAlignment: CrossAxisAlignment.start,
              children: items.map((item) =>
                Padding({
                  padding: EdgeInsets.only({ bottom: 2 }),
                  child: Text(`${item.footnoteNumber}. ${item.content}`, {
                    fontSize: 9,
                  }),
                })
              ),
            }),
          }),
        });
      },
      body: [
        ResetPageNumber({ style: "arabic", startAt: 1 }),

        Flow({
          children: [
            MetadataMarker({
              key: "chapterTitle",
              value: "Chapter 1: Layout & Decoration",
              child: Text("Chapter 1: Layout & Decoration", { fontSize: 24 }),
            }),
            SizedBox({ height: 15 }),

            textBlock(
              "The KeepTogether widget ensures that a heading and its subsequent content are not split across a page break."
            ),

            KeepTogether({
              first: textBlock("Section 1.1: DecoratedBox", { fontSize: 16 }),
              second: DecoratedBox({
                decoration: BoxDecoration({
                  border: Border.all({ width: 0.5 }),
                  color: "#EEEEEE",
                }),
                child: Padding({
                  padding: EdgeInsets.all(10),
                  child: Column({
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "This Column is inside a DecoratedBox, which provides a border, background color, and rounded corners."
                      ),
                      SizedBox({ height: 8 }),
                      Row({
                        children: [
                          Text("A dotted line leader: "),
                          Expanded({ child: Repeater(" .") }),
                        ],
                      }),
                    ],
                  }),
                }),
              }),
            }),

            SizedBox({ height: 25 }),

            MetadataMarker({
              key: "chapterTitle",
              value: "Chapter 2: Advanced Flow Control",
              child: Text("Chapter 2: Advanced Flow Control", { fontSize: 24 }),
            }),
            SizedBox({ height: 15 }),

            KeepTogether({
              first: textBlock("Section 2.1: Multi-Column Flow", {
                fontSize: 16,
              }),
              second: LineBreakConfiguration({
                mode: LineBreakMode.knuthPlass,
                child: MultiColumnFlow({
                  columnCount: 2,
                  columnSpacing: 15,
                  children: [
                    textBlock(
                      `This content is in a MultiColumnFlow. It automatically fills the first column, then flows into the second. If there is more content than can fit on this page, it will continue in columns on the next page.`
                    ),
                    textBlock(lipsum),
                    textBlock(lipsum.substring(0, 200) + "..."),
                  ],
                }),
              }),
            }),

            SizedBox({ height: 10 }),
            textBlock(
              "This text appears after the multi-column flow, demonstrating that normal flow resumes."
            ),
            SizedBox({ height: 10 }),

            KeepTogether({
              first: textBlock(
                "Section 2.2: Synced Columns (Dictionary Example)",
                { fontSize: 16 }
              ),
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
                    "Translation 1: This is where the translation would go, laid out in its own column."
                  ),
                  textBlock(
                    "Translation 2: And the translation for the second phrase appears here, on the same page."
                  ),
                  textBlock(
                    "Translation 3: This layout is useful for bilingual documents or manuals where descriptions must stay with their corresponding text."
                  ),
                ],
              }),
            }),

            FlowFill({
              child: SizedBox({ height: 0 }),
            }),

            MetadataMarker({
              key: "chapterTitle",
              value: "Chapter 3: Dynamic Content & Footnotes",
              child: Text("Chapter 3: Dynamic Content", { fontSize: 24 }),
            }),
            SizedBox({ height: 15 }),

            textBlock("Section 3.1: Automatic Footnotes", { fontSize: 16 }),

            FormattedText(
              "The line-breaking problem is informally called 'justification'.#footnote[This is the first footnote. It is automatically numbered and placed at the bottom of the page by the 'footnoteBuilder'.] Even when text is being typeset with ragged right margins, it needs to be broken into lines of approximately the same size.#footnote[This is the second footnote, demonstrating that multiple footnotes are handled correctly.]"
            ),

            SizedBox({ height: 25 }),

            textBlock("Section 3.2: Manual Footnotes", { fontSize: 16 }),
            SizedBox({ height: 5 }),

            Row({
              children: [
                Text(
                  "You can also create footnote markers manually. See here:"
                ),
                SizedBox({ width: 2 }),
                MetadataMarker({
                  key: "__footnote",
                  value: FootnoteLayoutInfo({
                    content:
                      "This is a manually-defined footnote. It is correctly numbered in sequence with the automatic ones.",
                  }),
                  child: Text("3", { fontSize: 8 }),
                }),
              ],
            }),

            FlowFill({
              child: Column({
                mainAxisAlignment: "center",
                crossAxisAlignment: "center",
                children: [
                  SizedBox({ height: 50 }),
                  Text("--- End of Document ---", {
                    fontSize: 16,
                    fontStyle: "italic",
                  }),
                ],
              }),
            }),
          ],
        }),
      ],
    }),
  });
}
