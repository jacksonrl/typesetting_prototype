import '../typesetting_prototype.dart';

enum PageNumberStyle {
  arabic,
  romanLower,
  romanUpper;

  String format(int number) {
    switch (this) {
      case PageNumberStyle.arabic:
        return number.toString();
      case PageNumberStyle.romanLower:
        return _toRoman(number).toLowerCase();
      case PageNumberStyle.romanUpper:
        return _toRoman(number);
    }
  }

  static String _toRoman(int num) {
    if (num < 1 || num > 3999) return num.toString();
    const values = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1];
    const numerals = ["M", "CM", "D", "CD", "C", "XC", "L", "XL", "X", "IX", "V", "IV", "I"];
    var result = '';
    for (int i = 0; i < values.length; i++) {
      while (num >= values[i]) {
        num -= values[i];
        result += numerals[i];
      }
    }
    return result;
  }
}

class PageNumberSettings {
  final PageNumberStyle style;
  final int startAt;

  const PageNumberSettings({this.style = PageNumberStyle.arabic, this.startAt = 1});
}

class FootnoteItem {
  final int footnoteNumber;
  final String content;

  const FootnoteItem({required this.footnoteNumber, required this.content});
}

class RenderPageLayout extends RenderNode {
  final PageSection? header;
  final PageSection? footer;
  final RenderNode body;
  final Widget Function(List<FootnoteItem>)? footnoteBuilder;

  final Map<int, ({RenderNode header, RenderNode footer, List<PositionedPrimitive> body, PageNumberSettings settings})>
  _finalPages = {};

  double pageContentHeight = 0;
  int get pageCount => _finalPages.length;

  RenderPageLayout({required this.header, required this.footer, required this.body, this.footnoteBuilder});

  List<MetadataRecord> buildPages(LayoutContext layoutContext) {
    _finalPages.clear();
    pageContentHeight = layoutContext.constraints.maxHeight;
    RenderNode? remainingBody = body;
    int currentPageIndex = 0;

    List<MetadataRecord> discoveredRecords = [];
    var runningSettings = const PageNumberSettings();

    final headerPrototypeNode = header?.prototype?.createRenderNode() ?? SizedBox.shrink().createRenderNode();
    headerPrototypeNode.layout(layoutContext);
    final footerPrototypeNode = footer?.prototype?.createRenderNode() ?? SizedBox.shrink().createRenderNode();
    footerPrototypeNode.layout(layoutContext);

    while (remainingBody != null) {
      final double headerHeight = header?.height ?? headerPrototypeNode.size.height;
      final double footerHeight = footer?.height ?? footerPrototypeNode.size.height;

      final contentHeight = pageContentHeight - headerHeight - footerHeight;
      if (contentHeight <= 0) break;

      if (remainingBody is! RenderSlice) throw TypeError();

      // footnote layout convergence
      SliceLayoutResult finalBodySliceResult;
      RenderNode? finalFootnoteBlock;
      double bodyAvailableHeight = contentHeight;
      List<MetadataRecord> currentMetadata = discoveredRecords.toList();

      int iteration = 0;
      const maxIterations = 5;

      while (true) {
        iteration++;
        if (iteration > maxIterations) {
          print("Warning: Footnote layout did not converge after $maxIterations iterations. Using last layout.");
          // On timeout, we must accept the last calculated slice as final
          final bodySliceContext = SliceLayoutContext(
            pwContext: layoutContext.pwContext,
            constraints: layoutContext.constraints,
            availableHeight: bodyAvailableHeight,
            metadata: currentMetadata,
          );
          finalBodySliceResult = remainingBody.layoutSlice(bodySliceContext);
          final footnotesOnThisPage = finalBodySliceResult.metadata
              .where((r) => r.key == '__footnote' && r.value is FootnoteLayoutInfo)
              .map((r) => r.value as FootnoteLayoutInfo)
              .toList();
          List<FootnoteItem> footnoteItems = [];
          for (int i = 0; i < footnotesOnThisPage.length; i++) {
            footnoteItems.add(FootnoteItem(footnoteNumber: i + 1, content: footnotesOnThisPage[i].content));
          }

          if (footnotesOnThisPage.isNotEmpty && footnoteBuilder != null) {
            final builder = footnoteBuilder!(footnoteItems).createRenderNode();
            builder.layout(layoutContext);
            finalFootnoteBlock = builder;
          } else {
            finalFootnoteBlock = null;
          }
          break;
        }

        final bodySliceContext = SliceLayoutContext(
          pwContext: layoutContext.pwContext,
          constraints: layoutContext.constraints,
          availableHeight: bodyAvailableHeight,
          metadata: currentMetadata,
        );
        final currentBodySlice = remainingBody.layoutSlice(bodySliceContext);

        final footnotesOnThisPage = currentBodySlice.metadata
            .where((r) => r.key == '__footnote' && r.value is FootnoteLayoutInfo)
            .map((r) => r.value as FootnoteLayoutInfo)
            .toList();

        final int previousFootnoteCount = discoveredRecords
            .where((r) => r.key == '__footnote' && r.value is FootnoteLayoutInfo)
            .length;

        List<FootnoteItem> footnoteItems = [];
        for (int i = 0; i < footnotesOnThisPage.length; i++) {
          footnoteItems.add(
            FootnoteItem(footnoteNumber: i + 1 + previousFootnoteCount, content: footnotesOnThisPage[i].content),
          );
        }

        double footnotesHeight = 0;
        RenderNode? currentFootnoteBlock;
        if (footnotesOnThisPage.isNotEmpty && footnoteBuilder != null) {
          final footnoteLayoutContext = LayoutContext(
            pwContext: layoutContext.pwContext,
            constraints: layoutContext.constraints,
            metadata: layoutContext.metadata,
          );
          final builder = footnoteBuilder!(footnoteItems).createRenderNode();
          footnotesHeight = builder.layout(footnoteLayoutContext).size.height;
          currentFootnoteBlock = builder;
        }

        final newBodyAvailableHeight = contentHeight - footnotesHeight;

        if ((newBodyAvailableHeight - bodyAvailableHeight).abs() < 1e-9) {
          finalBodySliceResult = currentBodySlice;
          finalFootnoteBlock = currentFootnoteBlock;
          break;
        } else {
          bodyAvailableHeight = (newBodyAvailableHeight < 0) ? 0 : newBodyAvailableHeight;
        }
      }
      final List<PositionedPrimitive> pagePrimitives = [];
      pagePrimitives.addAll(
        finalBodySliceResult.paintedPrimitives.map(
          (p) => PositionedPrimitive(p.node, p.offset + Offset(0, headerHeight)),
        ),
      );

      /*
      //could also do this to align to the bottom of the body
      if (finalFootnoteBlock != null) {
        final bodyConsumedHeight = finalBodySliceResult.consumedSize.height;
        final footnoteOffset = Offset(0, headerHeight + bodyConsumedHeight + 10.0);
        pagePrimitives.add(PositionedPrimitive(finalFootnoteBlock, footnoteOffset));
      }
      */

      if (finalFootnoteBlock != null) {
        final double bottomAlignedHeight = pageContentHeight - footerHeight - finalFootnoteBlock.size.height;
        final footnoteOffset = Offset(0, bottomAlignedHeight);
        pagePrimitives.add(PositionedPrimitive(finalFootnoteBlock, footnoteOffset));
      }

      for (final record in finalBodySliceResult.metadata) {
        if (record.key == RenderResetPageNumber.metadataKey) {
          if (record.value is PageNumberSettings) {
            runningSettings = record.value;
          }
        } else {
          record.pageNumber = currentPageIndex + 1;
          discoveredRecords.add(record);
        }
      }

      _finalPages[currentPageIndex] = (
        header: headerPrototypeNode,
        footer: footerPrototypeNode,
        body: pagePrimitives,
        settings: runningSettings,
      );

      remainingBody = finalBodySliceResult.remainder;
      currentPageIndex++;
    }
    return discoveredRecords;
  }

  /// Generates the mapping from absolute page number to its formatted string.
  /// This pass does not call the user-provided header/footer builders.
  Map<int, String> generatePageNumberMap({required int pageNumberOffset}) {
    if (pageCount == 0) return {};

    final Map<int, String> pageNumberMap = {};
    final List<SectionInfo> sections = [];
    int sectionStartPageIndex = 0;
    PageNumberSettings currentSectionSettings = _finalPages[0]!.settings;

    for (int i = 1; i < pageCount; i++) {
      final pageSettings = _finalPages[i]!.settings;
      if (pageSettings != currentSectionSettings) {
        sections.add((
          settings: currentSectionSettings,
          startPageIndex: sectionStartPageIndex,
          pageCount: i - sectionStartPageIndex,
        ));
        currentSectionSettings = pageSettings;
        sectionStartPageIndex = i;
      }
    }
    sections.add((
      settings: currentSectionSettings,
      startPageIndex: sectionStartPageIndex,
      pageCount: pageCount - sectionStartPageIndex,
    ));

    for (final section in sections) {
      for (int i = 0; i < section.pageCount; i++) {
        final globalPageIndex = section.startPageIndex + i;
        final localPageCounter = section.settings.startAt + i;
        final absolutePageNumber = pageNumberOffset + globalPageIndex + 1;
        pageNumberMap[absolutePageNumber] = section.settings.style.format(localPageCounter);
      }
    }
    return pageNumberMap;
  }

  /// Builds the final header and footer frames.
  /// This is the where the header/footer builders are called.
  void finalizeFrames({
    required LayoutContext layoutContext,
    required int totalPages,
    required int pageNumberOffset,
    required List<MetadataRecord> allRecords,
    required Map<int, String> pageNumberMap,
  }) {
    if (pageCount == 0) return;

    final List<SectionInfo> sections = [];
    int sectionStartPageIndex = 0;
    PageNumberSettings currentSectionSettings = _finalPages[0]!.settings;

    for (int i = 1; i < pageCount; i++) {
      final pageSettings = _finalPages[i]!.settings;
      if (pageSettings != currentSectionSettings) {
        sections.add((
          settings: currentSectionSettings,
          startPageIndex: sectionStartPageIndex,
          pageCount: i - sectionStartPageIndex,
        ));
        currentSectionSettings = pageSettings;
        sectionStartPageIndex = i;
      }
    }
    sections.add((
      settings: currentSectionSettings,
      startPageIndex: sectionStartPageIndex,
      pageCount: pageCount - sectionStartPageIndex,
    ));

    for (final section in sections) {
      for (int i = 0; i < section.pageCount; i++) {
        final globalPageIndex = section.startPageIndex + i;
        final pageData = _finalPages[globalPageIndex]!;
        final absolutePageNumber = pageNumberOffset + globalPageIndex + 1;

        final formattedPageNumber = pageNumberMap[absolutePageNumber] ?? '';
        final formattedTotalPages = section.settings.style.format(section.pageCount);

        final finalPageContext = PageContext(
          pageNumber: absolutePageNumber,
          totalPages: totalPages,
          settings: section.settings,
          sectionPageCount: section.pageCount,
          formattedPageNumber: formattedPageNumber,
          formattedTotalPages: formattedTotalPages,
          metadata: allRecords,
        );

        final knownHeaderHeight = pageData.header.size.height;
        final knownFooterHeight = pageData.footer.size.height;

        final headerConstraints = BoxConstraints(
          maxWidth: layoutContext.constraints.maxWidth,
          maxHeight: knownHeaderHeight,
        );

        final headerLayoutContext = layoutContext.copyWith(constraints: headerConstraints);

        final footerConstraints = BoxConstraints(
          maxWidth: layoutContext.constraints.maxWidth,
          maxHeight: knownFooterHeight,
        );
        final footerLayoutContext = layoutContext.copyWith(constraints: footerConstraints);

        final finalHeaderNode =
            header?.builder(finalPageContext).createRenderNode() ?? SizedBox(height: 0).createRenderNode();
        finalHeaderNode.layout(headerLayoutContext);
        final finalFooterNode =
            footer?.builder(finalPageContext).createRenderNode() ?? SizedBox(height: 0).createRenderNode();
        finalFooterNode.layout(footerLayoutContext);

        _finalPages[globalPageIndex] = (
          header: finalHeaderNode,
          footer: finalFooterNode,
          body: pageData.body,
          settings: pageData.settings,
        );
      }
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {}

  void paintPage(int pageIndex, PaintingContext context) {
    final pageData = _finalPages[pageIndex];
    if (pageData == null) return;
    pageData.header.paint(context, Offset.zero);
    for (final primitive in pageData.body) {
      primitive.node.paint(context, primitive.offset);
    }
    final footerY = pageContentHeight - pageData.footer.size.height;
    pageData.footer.paint(context, Offset(0, footerY));
  }

  @override
  LayoutResult performLayout() {
    return LayoutResult(size: Size.zero);
  }
}

class PageContext {
  /// The absolute page number within the entire document (e.g., 1, 2, 3, 4, ...).
  final int pageNumber;

  /// The total number of pages in the entire document.
  final int totalPages;

  /// The page number formatted according to the current section's style (e.g., "1", "IV", "iv").
  final String formattedPageNumber;

  /// The total pages of the CURRENT SECTION, formatted according to the section's style.
  final String formattedTotalPages;

  /// The raw integer count of pages in the current section.
  final int sectionPageCount;

  /// The raw settings used for this page's numbering.
  final PageNumberSettings settings;

  /// A list of all metadata records discovered up to this point in the document.
  final List<MetadataRecord> metadata;

  const PageContext({
    required this.pageNumber,
    required this.totalPages,
    required this.formattedPageNumber,
    required this.formattedTotalPages,
    required this.sectionPageCount,
    required this.settings,
    required this.metadata,
  });

  /// A helper to query metadata relevant to the current page.
  ///
  /// This simplifies the common task of finding "running header" text.
  ///
  /// - [key]: The user-defined key for the metadata (e.g., 'chapterTitle').
  /// - [policy]: Defines the strategy for retrieving the data. Defaults to
  ///   [MetadataRetrievalPolicy.onPageThenLatest], which is the most common
  ///   case for headers.
  ///
  /// Returns a list of values cast to type [T].
  List<T> getMetadata<T>({
    required String key,
    MetadataRetrievalPolicy policy = MetadataRetrievalPolicy.onPageThenLatest,
  }) {
    switch (policy) {
      case MetadataRetrievalPolicy.onPage:
        return metadata.where((r) => r.key == key && r.pageNumber == pageNumber).map((r) => r.value as T).toList();

      case MetadataRetrievalPolicy.latest:
        final record = metadata.lastWhere(
          (r) => r.key == key && r.pageNumber != null && r.pageNumber! <= pageNumber,
          orElse: () => MetadataRecord(key: '', value: null),
        );
        return record.value != null ? [record.value as T] : [];

      case MetadataRetrievalPolicy.onPageThenLatest:
        final onPageResults = getMetadata<T>(key: key, policy: MetadataRetrievalPolicy.onPage);
        if (onPageResults.isNotEmpty) {
          return onPageResults;
        }
        return getMetadata<T>(key: key, policy: MetadataRetrievalPolicy.latest);
    }
  }
}

class ResetPageNumber extends Widget {
  final PageNumberStyle style;
  final int startAt;

  const ResetPageNumber({this.style = PageNumberStyle.arabic, this.startAt = 1});

  @override
  RenderNode createRenderNode() {
    return RenderResetPageNumber(
      settings: PageNumberSettings(style: style, startAt: startAt),
    );
  }
}

class PageSection {
  final double? height;
  final Widget? prototype;
  final Widget Function(PageContext context) builder;
  PageSection.fixed({required this.height, required this.builder}) : prototype = null;
  PageSection.prototyped({required this.prototype, required this.builder}) : height = null;
}
