import 'package:pdf/pdf.dart';
import '../typesetting_prototype.dart';

class BorderSide {
  final Color color;
  final double width;

  const BorderSide({this.color = Color.black, this.width = 1.0});

  static const BorderSide none = BorderSide(width: 0.0);
}

class Border {
  final BorderSide top;
  final BorderSide left;
  final BorderSide right;
  final BorderSide bottom;

  const Border({
    this.top = BorderSide.none,
    this.left = BorderSide.none,
    this.right = BorderSide.none,
    this.bottom = BorderSide.none,
  });

  const Border.fromBorderSide(BorderSide side) : top = side, left = side, right = side, bottom = side;

  factory Border.all({Color color = Color.black, double width = 1.0}) =>
      Border.fromBorderSide(BorderSide(color: color, width: width));

  EdgeInsets get dimensions {
    return EdgeInsets.only(top: top.width, left: left.width, right: right.width, bottom: bottom.width);
  }
}

class BoxDecoration {
  final Border? border;

  const BoxDecoration({this.border});
}

class RenderPartialBorder extends RenderNode {
  final Border border;
  final bool drawTop;
  final bool drawLeft;
  final bool drawRight;
  final bool drawBottom;

  RenderPartialBorder(
    this.border, {
    required this.drawTop,
    required this.drawLeft,
    required this.drawRight,
    required this.drawBottom,
  });

  @override
  LayoutResult performLayout() {
    return LayoutResult(size: size);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final halfTop = border.top.width / 2;
    final halfLeft = border.left.width / 2;
    final halfRight = border.right.width / 2;
    final halfBottom = border.bottom.width / 2;

    final rect = PdfRect(offset.dx, context.pageHeight - offset.dy - size.height, size.width, size.height);

    final canvas = context.canvas;

    if (drawTop && border.top.width > 0) {
      canvas
        ..saveContext()
        ..setStrokeColor(PdfColor.fromInt(border.top.color.value))
        ..setLineWidth(border.top.width)
        ..moveTo(rect.left, rect.top + halfTop)
        ..lineTo(rect.right, rect.top + halfTop)
        ..strokePath()
        ..restoreContext();
    }
    if (drawBottom && border.bottom.width > 0) {
      canvas
        ..saveContext()
        ..setStrokeColor(PdfColor.fromInt(border.bottom.color.value))
        ..setLineWidth(border.bottom.width)
        ..moveTo(rect.left, rect.bottom - halfBottom)
        ..lineTo(rect.right, rect.bottom - halfBottom)
        ..strokePath()
        ..restoreContext();
    }
    if (drawLeft && border.left.width > 0) {
      canvas
        ..saveContext()
        ..setStrokeColor(PdfColor.fromInt(border.left.color.value))
        ..setLineWidth(border.left.width)
        ..moveTo(rect.left + halfLeft, rect.bottom)
        ..lineTo(rect.left + halfLeft, rect.top)
        ..strokePath()
        ..restoreContext();
    }
    if (drawRight && border.right.width > 0) {
      canvas
        ..saveContext()
        ..setStrokeColor(PdfColor.fromInt(border.right.color.value))
        ..setLineWidth(border.right.width)
        ..moveTo(rect.right - halfRight, rect.bottom)
        ..lineTo(rect.right - halfRight, rect.top)
        ..strokePath()
        ..restoreContext();
    }
  }
}
