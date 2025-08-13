function defineDocument() {
  return Document({
    body: PageLayout({
      header: PageSection.fixed({
        height: 25,
        builder: (context) => {
          const titles = getMetadata(context, "chapterTitle");
          const title = titles.length > 0 ? titles[0] : "JS Showcase";

          return DecoratedBox({
            decoration: BoxDecoration({
              border: Border({ bottom: BorderSide({ width: 0.5 }) }),
            }),
            child: Padding({
              padding: EdgeInsets.only({ bottom: 5 }),
              child: Row({
                children: [
                  Text(title, { fontSize: 9 }),
                  Expanded({ child: SizedBox({}) }),
                  Text(`Page ${context.formattedPageNumber}`, { fontSize: 9 }),
                ],
              }),
            }),
          });
        },
      }),

      footnoteBuilder: (items) => {
        return DecoratedBox({
          decoration: BoxDecoration({
            border: Border({ top: BorderSide({ width: 0.5 }) }),
          }),
          child: Padding({
            padding: EdgeInsets.only({ top: 5, left: 10, right: 10 }),
            child: Column({
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
        Flow({
          children: [
            SizedBox({ height: 10 }),
            MetadataMarker({
              key: "chapterTitle",
              value: "Chapter 1: Automatic Footnotes",
              child: Text("Testing Metadata and Footnotes", { fontSize: 22 }),
            }),

            SizedBox({ height: 15 }),

            FormattedText(
              "The line-breaking problem is informally called the problem of 'justification', since it is the 'J' of 'H & J' (hyphenation and justification) in today's word-processing systems.#footnote[This is the first footnote. It is automatically numbered and placed at the bottom of the page.] Even when text is being typeset with ragged right margins, it needs to be broken into lines of approximately the same size.#footnote[This is the second footnote, demonstrating that multiple footnotes on the same page are handled correctly.]"
            ),

            SizedBox({ height: 25 }),

            MetadataMarker({
              key: "chapterTitle",
              value: "Chapter 2: Manual Footnotes",
              child: Underline({
                child: Text("Manual Footnote Creation", { fontSize: 18 }),
              }),
            }),

            SizedBox({ height: 10 }),

            Row({
              children: [
                Text("This is a manually created footnote marker"),
                MetadataMarker({
                  key: "__footnote",
                  value: FootnoteLayoutInfo({
                    content:
                      "This is a manually-defined footnote's text. It will be auto-numbered correctly after the others.",
                  }),
                  child: Text("3", { fontSize: 8 }),
                }),
              ],
            }),

            FlowFill({
              child: SizedBox({ height: 0 }),
            }),

            MetadataMarker({
              key: "chapterTitle",
              value: "Chapter 3: After the Page Break",
              child: Text(
                "This text appears on the next page, showing the running header has updated.",
                { fontSize: 14 }
              ),
            }),
          ],
        }),
      ],
    }),
  });
}
