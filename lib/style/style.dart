class Color {
  final int value;
  const Color(this.value);

  factory Color.fromHex(String hexString) {
    final hex = hexString.replaceFirst('#', '').toUpperCase();
    String finalHex;

    if (hex.length == 6) {
      finalHex = 'FF$hex';
    } else if (hex.length == 8) {
      finalHex = hex;
    } else {
      throw ArgumentError('Invalid hex color string: "$hexString". Must be in the format #RRGGBB or #AARRGGBB.');
    }

    return Color(int.parse(finalHex, radix: 16));
  }

  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);
  static const Color red = Color(0xFFFF0000);
  static const Color green = Color(0xFF00FF00);
  static const Color blue = Color(0xFF0000FF);
}
