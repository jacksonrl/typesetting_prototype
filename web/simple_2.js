function defineDocument() {
  return Document({
    body: PageLayout({
      header: PageSection.fixed({
        height: 30,
        builder: (context) =>
          Text(`Header from JS! Page: ${context.formattedPageNumber}`, {
            fontSize: 10,
          }),
      }),
      footer: PageSection.fixed({
        height: 20,
        builder: (context) =>
          Text(`Footer - Total Pages: ${context.totalPages}`, { fontSize: 10 }),
      }),
      body: [
        Flow({
          children: [
            DecoratedBox({
              decoration: BoxDecoration({
                border: Border({ bottom: BorderSide({ width: 0.5 }) }),
              }),
              child: Padding({
                padding: EdgeInsets.only({ bottom: 5 }),
                child: Text(
                  "Hello from a JavaScript script with headers and footers!",
                  {
                    fontSize: 18,
                  }
                ),
              }),
            }),
            FormattedText(
              "The line-breaking problem is informally called the problem of 'justification', since it is the 'J' of 'H & J' (hyphenation and justification) in today's word-processing systems.#footnote[This is the first footnote. It is automatically numbered.] Even when text is being typeset with ragged right margins, it needs to be broken into lines of approximately the same size.#footnote[This is the second footnote, demonstrating that.]"
            ),
          ],
        }),
        Row({
          children: [
            Text("Hello from a JavaScript script ", {
              fontSize: 18,
            }),
            Text("with headers and footers!", {
              fontSize: 18,
            }),
          ],
        }),
      ],
    }),
  });
}
