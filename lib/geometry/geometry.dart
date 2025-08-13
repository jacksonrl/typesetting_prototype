import 'dart:math';

class Offset {
  final double dx;
  final double dy;
  const Offset(this.dx, this.dy);
  static const Offset zero = Offset(0.0, 0.0);
  Offset operator +(Offset other) => Offset(dx + other.dx, dy + other.dy);
  @override
  String toString() => 'Offset(x: ${dx.toStringAsFixed(1)}, y: ${dy.toStringAsFixed(1)})';
}

class Size {
  final double width;
  final double height;
  const Size(this.width, this.height);
  static const Size zero = Size(0.0, 0.0);
  @override
  String toString() => 'Size(w: ${width.toStringAsFixed(1)}, h: ${height.toStringAsFixed(1)})';
}

class EdgeInsets {
  final double left, top, right, bottom;

  const EdgeInsets.fromLTRB(this.left, this.top, this.right, this.bottom);

  const EdgeInsets.zero() : bottom = 0.0, top = 0.0, left = 0.0, right = 0.0;
  const EdgeInsets.all(double value) : this.fromLTRB(value, value, value, value);
  const EdgeInsets.symmetric({double horizontal = 0.0, double vertical = 0.0})
    : left = horizontal,
      right = horizontal,
      top = vertical,
      bottom = vertical;
  const EdgeInsets.only({this.left = 0.0, this.top = 0.0, this.right = 0.0, this.bottom = 0.0});
  double get horizontal => left + right;
  double get vertical => top + bottom;
}

enum CrossAxisAlignment { start, end, center, stretch }

enum MainAxisAlignment { start, end, center }

class BoxConstraints {
  final double minWidth, maxWidth, minHeight, maxHeight;

  const BoxConstraints({
    this.minWidth = 0.0,
    this.maxWidth = double.infinity,
    this.minHeight = 0.0,
    this.maxHeight = double.infinity,
  });

  Size get biggest {
    assert(maxWidth.isFinite, 'Cannot get the biggest size of an unbounded BoxConstraints. The maxWidth is infinite.');
    assert(
      maxHeight.isFinite,
      'Cannot get the biggest size of an unbounded BoxConstraints. The maxHeight is infinite.',
    );
    return Size(maxWidth, maxHeight);
  }

  BoxConstraints loosen() {
    return BoxConstraints(minWidth: 0.0, maxWidth: maxWidth, minHeight: 0.0, maxHeight: maxHeight);
  }

  Size constrain(Size size) {
    return Size(max(minWidth, min(size.width, maxWidth)), max(minHeight, min(size.height, maxHeight)));
  }

  BoxConstraints deflate(EdgeInsets insets) {
    final double horizontal = insets.horizontal;
    final double vertical = insets.vertical;
    final double newMaxWidth = max(0.0, maxWidth - horizontal);
    final double newMaxHeight = max(0.0, maxHeight - vertical);

    return BoxConstraints(
      minWidth: max(0.0, minWidth - horizontal),
      maxWidth: newMaxWidth,
      minHeight: max(0.0, minHeight - vertical),
      maxHeight: newMaxHeight,
    );
  }

  @override
  String toString() {
    return 'BoxConstraints(minW: $minWidth, maxW: $maxWidth, minH: $minHeight, maxH: $maxHeight)';
  }
}
