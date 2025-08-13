class ScriptDocument {
  constructor({ body, pageFormat, pageMargin }) {
    this._type = "ScriptDocument";
    this.body = body;
    this.pageFormat = pageFormat || ScriptPdfPageFormat.a4;
    this.pageMargin = pageMargin || {
      left: 30,
      top: 30,
      right: 30,
      bottom: 30,
    };
  }
}

class ScriptPageLayout {
  constructor({ header, footer, body }) {
    this._type = "ScriptPageLayout";
    this.header = header;
    this.footer = footer;
    this.body = body || [];
  }
}

class ScriptPageSection {
  constructor({ fixedHeight, builder }) {
    this._type = "ScriptPageSection";
    this.fixedHeight = fixedHeight;
    this.builder = builder;
  }
}

const ScriptPdfPageFormat = {
  a4: { width: 595.27, height: 841.88 },
};

class ScriptText {
  constructor(text, { fontSize } = {}) {
    this._type = "ScriptText";
    this.text = text;
    this.fontSize = fontSize || 12.0;
  }
}

function defineDocument() {
  return new ScriptDocument({
    body: new ScriptPageLayout({
      header: new ScriptPageSection({
        fixedHeight: 30,
        builder: (context) =>
          new ScriptText(
            `Header from JS! Page: ${context.formattedPageNumber}`,
            { fontSize: 10 }
          ),
      }),
      footer: new ScriptPageSection({
        fixedHeight: 20,
        builder: (context) =>
          new ScriptText(`Footer - Total Pages: ${context.totalPages}`, {
            fontSize: 10,
          }),
      }),
      body: [
        new ScriptText(
          "Hello from a JavaScript script with headers and footers!",
          { fontSize: 18 }
        ),
      ],
    }),
  });
}
