import 'package:typesetting_prototype/typesetting_prototype.dart';

class MetadataRecord {
  final String key;
  final dynamic value;
  int? pageNumber;
  String formattedPageNumber = "";

  MetadataRecord({required this.key, required this.value, this.pageNumber});

  @override
  String toString() {
    return 'key: $key, value: $value, pageNumber: $pageNumber, formattedPageNumber: $formattedPageNumber';
  }
}

enum MetadataRetrievalPolicy { onPage, latest, onPageThenLatest }

typedef SectionInfo = ({PageNumberSettings settings, int startPageIndex, int pageCount});

class DocumentMetadataRegistry {
  List<MetadataRecord> records = [];

  void add(String key, dynamic value, int pageNumber) {
    records.add(MetadataRecord(key: key, value: value, pageNumber: pageNumber));
  }

  void updateFormattedNumbers(Map<int, String> pageNumberMap) {
    for (final record in records) {
      record.formattedPageNumber = pageNumberMap[record.pageNumber] ?? record.pageNumber.toString();
    }
  }

  void finalizePageNumbers(int offset) {
    for (final record in records) {
      record.pageNumber = (record.pageNumber ?? 0) + offset;
    }
  }
}

class RenderMetadataMarker extends RenderNode with RenderObjectWithChildMixin, RenderSlice {
  final String key;
  final dynamic value;
  RenderMetadataMarker({required this.key, required this.value});

  List<MetadataRecord> get _ownMetadata => [MetadataRecord(key: key, value: value)];

  @override
  LayoutResult performLayout() {
    if (child != null) {
      final childResult = child!.layout(layoutContext!);

      return LayoutResult(size: childResult.size, metadata: [..._ownMetadata, ...childResult.metadata]);
    } else {
      size = Size.zero;
      return LayoutResult(size: Size.zero, metadata: _ownMetadata);
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    child?.paint(context, offset);
  }

  @override
  SliceLayoutResult layoutSlice(SliceLayoutContext context) {
    if (child == null) {
      return SliceLayoutResult(paintedPrimitives: [], consumedSize: Size.zero, remainder: null, metadata: _ownMetadata);
    }

    if (child is! RenderSlice) {
      final childLayoutContext = LayoutContext(
        pwContext: context.pwContext,
        constraints: context.constraints,
        metadata: context.metadata,
      );
      final childResult = child!.layout(childLayoutContext);
      final combinedMetadata = [..._ownMetadata, ...childResult.metadata];

      if (childResult.size.height <= context.availableHeight) {
        return SliceLayoutResult(
          paintedPrimitives: [PositionedPrimitive(this, Offset.zero)],
          consumedSize: childResult.size,
          remainder: null,
          metadata: combinedMetadata,
        );
      } else {
        return SliceLayoutResult(
          paintedPrimitives: [],
          consumedSize: Size.zero,
          remainder: this,
          metadata: _ownMetadata,
        );
      }
    }

    final childResult = (child as RenderSlice).layoutSlice(context);
    final combinedMetadata = [..._ownMetadata, ...childResult.metadata];
    final RenderNode? finalRemainder = childResult.remainder != null
        ? (RenderMetadataMarker(key: key, value: value)
            ..child = childResult.remainder
            ..parent = parent)
        : null;

    return SliceLayoutResult(
      paintedPrimitives: childResult.paintedPrimitives,
      consumedSize: childResult.consumedSize,
      remainder: finalRemainder,
      metadata: combinedMetadata,
    );
  }
}
