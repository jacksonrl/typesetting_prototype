import 'package:typesetting_prototype/typesetting_prototype.dart';

/// Describes how to size a table column.
abstract class TableColumnWidth {
  const TableColumnWidth();
}

/// A column with a fixed width in points.
class FixedColumnWidth extends TableColumnWidth {
  final double width;
  const FixedColumnWidth(this.width);
}

/// A column that sizes to a fraction of the available width.
///
/// After all [FixedColumnWidth] and [IntrinsicColumnWidth] columns have been
/// sized, the remaining width is divided among the [FlexColumnWidth] columns

/// according to their flex factor.
class FlexColumnWidth extends TableColumnWidth {
  final double flex;
  const FlexColumnWidth([this.flex = 1.0]);
}

/// A column that sizes to the widest content within it.
///
/// This is the most expensive sizing algorithm, as it requires laying out
/// the contents of every cell in the column twice: once to measure the
/// ideal width, and a second time to paint the cell within its final constraints.
class IntrinsicColumnWidth extends TableColumnWidth {
  final double flex;
  const IntrinsicColumnWidth({this.flex = 1.0});
}

enum TableCellVerticalAlignment { top, middle, bottom, fill }

/// A single cell in a [Table].
class TableCell extends Widget {
  final Widget child;
  final int rowSpan;
  final int colSpan;
  final TableCellVerticalAlignment verticalAlignment;

  const TableCell({
    required this.child,
    this.rowSpan = 1,
    this.colSpan = 1,
    this.verticalAlignment = TableCellVerticalAlignment.top,
  });

  @override
  RenderNode createRenderNode() {
    throw UnimplementedError('TableCell is a data-only widget for use within a Table.');
  }
}

class TableRow {
  final List<TableCell> children;
  const TableRow({this.children = const []});
}

/// A widget that arranges its children in a table.
class Table extends Widget {
  final List<TableRow> children;
  final Map<int, TableColumnWidth> columnWidths;
  final TableCellVerticalAlignment defaultVerticalAlignment;

  const Table({
    this.children = const [],
    this.columnWidths = const {},
    this.defaultVerticalAlignment = TableCellVerticalAlignment.top,
  });

  @override
  RenderNode createRenderNode() {
    return RenderTable(rows: children, columnWidths: columnWidths, defaultVerticalAlignment: defaultVerticalAlignment);
  }
}

class RenderTable extends RenderNode with RenderSlice {
  final List<TableRow> rows;
  final Map<int, TableColumnWidth> columnWidths;
  final TableCellVerticalAlignment defaultVerticalAlignment;

  RenderTable({required this.rows, required this.columnWidths, required this.defaultVerticalAlignment});

  int _firstRow = 0;

  List<double> _columnWidths = [];

  final List<double> _rowHeights = [];
  late List<List<RenderNode?>> _children;
  late List<List<TableCell?>> _cells;
  int _columnCount = 0;
  bool _isPrepared = false;

  void _prepareCellsAndChildren() {
    if (_isPrepared) return;

    if (rows.isEmpty) {
      _columnCount = 0;
      _children = [];
      _cells = [];
      _isPrepared = true;
      return;
    }

    _columnCount = 0;
    for (final row in rows) {
      int count = 0;
      for (final cell in row.children) {
        count += cell.colSpan;
      }
      if (count > _columnCount) {
        _columnCount = count;
      }
    }

    if (_columnCount == 0) {
      _children = [];
      _cells = [];
      _isPrepared = true;
      return;
    }

    _children = List.generate(rows.length, (_) => List.filled(_columnCount, null));
    _cells = List.generate(rows.length, (_) => List.filled(_columnCount, null));

    final occupied = List.generate(rows.length, (_) => List.filled(_columnCount, false));

    for (int y = 0; y < rows.length; y++) {
      int x = 0;
      for (final cell in rows[y].children) {
        while (x < _columnCount && occupied[y][x]) {
          x++;
        }
        if (x < _columnCount) {
          final renderNode = cell.child.createRenderNode();
          renderNode.parent = this;
          _children[y][x] = renderNode;
          _cells[y][x] = cell;

          for (int dy = 0; dy < cell.rowSpan; dy++) {
            for (int dx = 0; dx < cell.colSpan; dx++) {
              if (y + dy < rows.length && x + dx < _columnCount) {
                occupied[y + dy][x + dx] = true;
              }
            }
          }
          x += cell.colSpan;
        }
      }
    }
    _isPrepared = true;
  }

  List<double> _calculateColumnWidths(BoxConstraints constraints, LayoutContext context) {
    final List<double> flexFactors = List.filled(_columnCount, 0.0);
    final List<double> finalWidths = List.filled(_columnCount, 0.0);
    final List<bool> isFlex = List.filled(_columnCount, false);

    double totalFlex = 0;
    double fixedAndIntrinsicWidth = 0;

    for (int i = 0; i < _columnCount; i++) {
      final width = columnWidths[i];
      if (width is FixedColumnWidth) {
        finalWidths[i] = width.width;
        fixedAndIntrinsicWidth += width.width;
      } else if (width is IntrinsicColumnWidth) {
        double maxIntrinsicWidth = 0;
        for (int j = 0; j < rows.length; j++) {
          final cell = _cells[j][i];
          final child = _children[j][i];
          if (child != null && cell != null && cell.colSpan == 1) {
            // Layout with infinite width to find the preferred size.
            final measureResult = child.layout(context.copyWith(constraints: const BoxConstraints()));
            if (measureResult.size.width > maxIntrinsicWidth) {
              maxIntrinsicWidth = measureResult.size.width;
            }
          }
        }
        finalWidths[i] = maxIntrinsicWidth;
        fixedAndIntrinsicWidth += maxIntrinsicWidth;
        flexFactors[i] = width.flex;
        totalFlex += width.flex;
        isFlex[i] = true;
      } else if (width is FlexColumnWidth) {
        flexFactors[i] = width.flex;
        totalFlex += width.flex;
        isFlex[i] = true;
      } else {
        flexFactors[i] = 1.0;
        totalFlex += 1.0;
        isFlex[i] = true;
      }
    }

    final double availableWidth = constraints.maxWidth;
    double remainingWidth = (availableWidth - fixedAndIntrinsicWidth).clamp(0.0, double.infinity);

    if (totalFlex > 0) {
      for (int i = 0; i < _columnCount; i++) {
        if (isFlex[i]) {
          final share = remainingWidth * (flexFactors[i] / totalFlex);
          finalWidths[i] += share;
        }
      }
    }

    return finalWidths;
  }

  double _layoutRowAndDetermineHeight(int rowIndex, LayoutContext context) {
    double maxRowHeight = 0.0;
    final List<RenderNode?> cellsToLayout = [];
    final List<int> cellsToLayoutColumnIndex = [];

    for (int col = 0; col < _columnCount; col++) {
      final child = _children[rowIndex][col];
      if (child != null) {
        cellsToLayout.add(child);
        cellsToLayoutColumnIndex.add(col);

        final cell = _cells[rowIndex][col]!;
        final cellWidth = _getSpanWidth(col, cell.colSpan);
        final cellConstraints = BoxConstraints(maxWidth: cellWidth);

        child.layout(context.copyWith(constraints: cellConstraints));

        final heightPerSpannedRow = child.size.height / cell.rowSpan;
        if (heightPerSpannedRow > maxRowHeight) {
          maxRowHeight = heightPerSpannedRow;
        }
      }
    }

    for (int col = 0; col < _columnCount; col++) {
      for (int y = rowIndex; y >= 0; y--) {
        final cell = _cells[y][col];
        if (cell != null && y + cell.rowSpan > rowIndex) {
          final child = _children[y][col]!;
          final heightPerSpannedRow = child.size.height / cell.rowSpan;
          if (heightPerSpannedRow > maxRowHeight) {
            maxRowHeight = heightPerSpannedRow;
          }
          break;
        }
      }
    }

    return maxRowHeight;
  }

  double _getSpanWidth(int startColumn, int colSpan) {
    double width = 0;
    for (int i = 0; i < colSpan; i++) {
      if (startColumn + i < _columnCount) {
        width += _columnWidths[startColumn + i];
      }
    }
    return width;
  }

  @override
  LayoutResult performLayout() {
    _isPrepared = false;
    _prepareCellsAndChildren();

    final layoutContext = this.layoutContext!;
    final constraints = this.constraints!;

    _columnWidths = _calculateColumnWidths(constraints, layoutContext);

    _rowHeights.clear();
    double totalHeight = 0;
    for (int i = 0; i < rows.length; i++) {
      final rowHeight = _layoutRowAndDetermineHeight(i, layoutContext);
      _rowHeights.add(rowHeight);
      totalHeight += rowHeight;
    }

    final totalWidth = _columnWidths.fold(0.0, (a, b) => a + b);
    size = Size(totalWidth, totalHeight);
    return LayoutResult(size: size); // TODO: Aggregate metadata
  }

  @override
  SliceLayoutResult layoutSlice(SliceLayoutContext context) {
    _isPrepared = false;
    _prepareCellsAndChildren();

    final layoutContext = LayoutContext(
      pwContext: context.pwContext,
      constraints: context.constraints,
      metadata: context.metadata,
    );

    _columnWidths = _calculateColumnWidths(context.constraints, layoutContext);

    final List<PositionedPrimitive> placedThisSlice = [];
    _rowHeights.clear();
    double currentY = 0;
    int rowsInSlice = 0;

    for (int i = _firstRow; i < rows.length; i++) {
      final rowHeight = _layoutRowAndDetermineHeight(i, layoutContext);

      if (currentY + rowHeight > context.availableHeight && rowsInSlice > 0) {
        break;
      }

      _rowHeights.add(rowHeight);
      currentY += rowHeight;
      rowsInSlice++;

      if (currentY > context.availableHeight) {
        if (rowsInSlice == 1) {
          throw Exception(
            'Layout Error: A row in a Table is taller (${rowHeight.toStringAsFixed(1)}pt) '
            'than the available page height (${context.availableHeight.toStringAsFixed(1)}pt). '
            'Table rows cannot be split across pages.',
          );
        }
        break;
      }
    }

    double rowOffsetY = 0;
    for (int i = 0; i < rowsInSlice; i++) {
      final rowIndex = _firstRow + i;
      final rowHeight = _rowHeights[i];
      double cellOffsetX = 0;

      for (int col = 0; col < _columnCount; col++) {
        final child = _children[rowIndex][col];
        final cell = _cells[rowIndex][col];

        if (child != null && cell != null) {
          double childOffsetY = 0;
          final alignment = cell.verticalAlignment;

          double effectiveCellHeight = 0;
          for (int spanY = 0; spanY < cell.rowSpan; spanY++) {
            if (i + spanY < _rowHeights.length) {
              effectiveCellHeight += _rowHeights[i + spanY];
            }
          }

          switch (alignment) {
            case TableCellVerticalAlignment.top:
              childOffsetY = 0;
              break;
            case TableCellVerticalAlignment.middle:
              childOffsetY = (effectiveCellHeight - child.size.height) / 2;
              break;
            case TableCellVerticalAlignment.bottom:
              childOffsetY = effectiveCellHeight - child.size.height;
              break;
            case TableCellVerticalAlignment.fill:
              final cellWidth = _getSpanWidth(col, cell.colSpan);
              final fillConstraints = BoxConstraints(
                minWidth: cellWidth,
                maxWidth: cellWidth,
                minHeight: effectiveCellHeight,
                maxHeight: effectiveCellHeight,
              );
              final fillLayoutContext = LayoutContext(
                pwContext: context.pwContext,
                constraints: fillConstraints,
                metadata: context.metadata,
              );
              child.layout(fillLayoutContext);
              childOffsetY = 0;
              childOffsetY = 0;
              break;
          }

          placedThisSlice.add(PositionedPrimitive(child, Offset(cellOffsetX, rowOffsetY + childOffsetY)));
        }

        if (col < _columnCount) {
          cellOffsetX += _columnWidths[col];
        }
      }
      rowOffsetY += rowHeight;
    }

    RenderTable? remainder;
    final lastRowInSlice = _firstRow + rowsInSlice;
    if (lastRowInSlice < rows.length) {
      remainder =
          RenderTable(rows: rows, columnWidths: columnWidths, defaultVerticalAlignment: defaultVerticalAlignment)
            .._firstRow = lastRowInSlice
            ..parent = parent;
    }

    final consumedWidth = _columnWidths.fold(0.0, (a, b) => a + b);
    final consumedHeight = _rowHeights.fold(0.0, (a, b) => a + b);

    return SliceLayoutResult(
      paintedPrimitives: placedThisSlice,
      consumedSize: Size(consumedWidth, consumedHeight),
      remainder: remainder,
      metadata: [], // TODO: Aggregate metadata from child layouts
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {}
}
