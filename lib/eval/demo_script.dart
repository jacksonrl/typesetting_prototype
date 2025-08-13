import 'script_stdlib.dart';

final lipsum =
    'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.';

ScriptDocument main() {
  return ScriptDocument(
    pageMargin: ScriptEdgeInsets.symmetric(horizontal: 40.0, vertical: 30.0),
    tocBuilder: (registry) {
      return ScriptPageLayout(
        header: ScriptPageSection.fixed(
          height: 30.0,
          builder: (context) => ScriptText('Table of Contents', fontSize: 24.0),
        ),
        footer: ScriptPageSection.fixed(
          height: 20.0,
          builder: (context) => ScriptText('Page ${context.formattedPageNumber}', fontSize: 10.0),
        ),
        body: [
          ScriptResetPageNumber(style: ScriptPageNumberStyle.romanLower),
          ScriptFlowFill(
            child: ScriptColumn(
              mainAxisAlignment: ScriptMainAxisAlignment.center,
              crossAxisAlignment: ScriptCrossAxisAlignment.center,
              children: [
                ScriptSizedBox(height: 20.0),
                ScriptSizedBox(
                  width: 300.0,
                  child: ScriptColumn(
                    crossAxisAlignment: ScriptCrossAxisAlignment.stretch,
                    children: [
                      ScriptPadding(
                        padding: ScriptEdgeInsets.only(bottom: 4.0),
                        child: ScriptRow(
                          children: [
                            ScriptText('${registry.records[1].value}'),
                            ScriptExpanded(
                              child: ScriptPadding(
                                padding: ScriptEdgeInsets.symmetric(horizontal: 5.0),
                                child: ScriptRepeater('.'),
                              ),
                            ),
                            ScriptText(registry.records[0].formattedPageNumber),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    },
    body: ScriptPageLayout(
      header: ScriptPageSection.prototyped(
        prototype: ScriptPadding(
          padding: ScriptEdgeInsets.only(bottom: 10.0),
          child: ScriptText('Chapter Title Placeholder', fontSize: 10.0),
        ),
        builder: (context) {
          //final titles = context.getMetadata<String>(key: 'chapterTitle').join(" - ");
          return ScriptPadding(padding: ScriptEdgeInsets.only(bottom: 10.0), child: ScriptText("test", fontSize: 10.0));
        },
      ),
      footer: ScriptPageSection.fixed(
        height: 20.0,
        builder: (context) =>
            ScriptText('Page ${context.formattedPageNumber} of ${context.formattedTotalPages}', fontSize: 10.0),
      ),
      footnoteBuilder: (List<ScriptFootnoteItem> footnoteItems) {
        return ScriptLineBreakConfiguration(
          mode: ScriptLineBreakMode.knuthPlass,
          child: ScriptDecoratedBox(
            decoration: ScriptBoxDecoration(border: ScriptBorder(top: ScriptBorderSide(width: 0.5))),
            child: ScriptColumn(children: [ScriptText("my text")]),
          ),
        );
      },
      body: [
        ScriptMetadataMarker(
          key: '__footnote',
          value: ScriptFootnoteLayoutInfo(content: "hello footnote", position: 0.0, number: 1),
          child: ScriptText('A manual footnote¹'),
        ),

        ScriptResetPageNumber(style: ScriptPageNumberStyle.arabic, startAt: 1),
        ScriptMetadataMarker(key: 'chapterTitle', value: 'Chapter 1: The Beginning', child: ScriptText("my chapter")),
      ],
    ),
  );
}
