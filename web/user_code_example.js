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
        Text("Hello from a JavaScript script with headers and footers!", {
          fontSize: 18,
        }),
        Text("The editor understands the library classes now.", {
          fontSize: 18,
        }),
      ],
    }),
  });
}
