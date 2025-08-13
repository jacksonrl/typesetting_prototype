import 'package:typesetting_prototype/platform/file_provider_service.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

sealed class Font {
  const Font();

  static const helvetica = _BuiltInFont(BuiltInFontName.helvetica);
  static const helveticaBold = _BuiltInFont(BuiltInFontName.helveticaBold);
  static const helveticaOblique = _BuiltInFont(BuiltInFontName.helveticaOblique);
  static const helveticaBoldOblique = _BuiltInFont(BuiltInFontName.helveticaBoldOblique);

  static const times = _BuiltInFont(BuiltInFontName.times);
  static const timesBold = _BuiltInFont(BuiltInFontName.timesBold);
  static const timesItalic = _BuiltInFont(BuiltInFontName.timesItalic);
  static const timesBoldItalic = _BuiltInFont(BuiltInFontName.timesBoldItalic);

  static const courier = _BuiltInFont(BuiltInFontName.courier);
  static const courierBold = _BuiltInFont(BuiltInFontName.courierBold);
  static const courierOblique = _BuiltInFont(BuiltInFontName.courierOblique);
  static const courierBoldOblique = _BuiltInFont(BuiltInFontName.courierBoldOblique);
}

enum FontWeight { normal, bold }

enum FontStyle { normal, italic }

enum BuiltInFontName {
  helvetica,
  helveticaBold,
  helveticaOblique,
  helveticaBoldOblique,

  times,
  timesBold,
  timesItalic,
  timesBoldItalic,

  courier,
  courierBold,
  courierOblique,
  courierBoldOblique,
}

class _BuiltInFont extends Font {
  final BuiltInFontName name;
  const _BuiltInFont(this.name);
}

class TtfFont extends Font {
  final String path;
  const TtfFont(this.path);
}

class FontFamily {
  final Font regular;
  final Font bold;
  final Font italic;
  final Font boldItalic;

  const FontFamily({required this.regular, required this.bold, required this.italic, required this.boldItalic});

  factory FontFamily.fromFont(Font font) {
    return FontFamily(regular: font, bold: font, italic: font, boldItalic: font);
  }

  static final helvetica = FontFamily(
    regular: Font.helvetica,
    bold: Font.helveticaBold,
    italic: Font.helveticaOblique,
    boldItalic: Font.helveticaBoldOblique,
  );

  static final times = FontFamily(
    regular: Font.times,
    bold: Font.timesBold,
    italic: Font.timesItalic,
    boldItalic: Font.timesBoldItalic,
  );

  static final courier = FontFamily(
    regular: Font.courier,
    bold: Font.courierBold,
    italic: Font.courierOblique,
    boldItalic: Font.courierBoldOblique,
  );

  Font getVariant(FontWeight weight, FontStyle style) {
    if (weight == FontWeight.bold && style == FontStyle.italic) {
      return boldItalic;
    }
    if (weight == FontWeight.bold) {
      return bold;
    }
    if (style == FontStyle.italic) {
      return italic;
    }
    return regular;
  }
}

class FontManager {
  static PdfFont getFont(Font font, pw.Context context) {
    return switch (font) {
      _BuiltInFont() => switch (font.name) {
        BuiltInFontName.helvetica => pw.Font.helvetica().getFont(context),
        BuiltInFontName.helveticaBold => pw.Font.helveticaBold().getFont(context),
        BuiltInFontName.helveticaOblique => pw.Font.helveticaBoldOblique().getFont(context),
        BuiltInFontName.helveticaBoldOblique => pw.Font.helveticaBoldOblique().getFont(context),
        BuiltInFontName.times => pw.Font.times().getFont(context),
        BuiltInFontName.timesBold => pw.Font.timesBold().getFont(context),
        BuiltInFontName.timesItalic => pw.Font.timesItalic().getFont(context),
        BuiltInFontName.timesBoldItalic => pw.Font.timesBoldItalic().getFont(context),
        BuiltInFontName.courier => pw.Font.courier().getFont(context),
        BuiltInFontName.courierBold => pw.Font.courierBold().getFont(context),
        BuiltInFontName.courierOblique => pw.Font.courierBoldOblique().getFont(context),
        BuiltInFontName.courierBoldOblique => pw.Font.courierBoldOblique().getFont(context),
      },
      TtfFont() =>
        getFileProvider().existsSync(font.path)
            ? pw.Font.ttf(getFileProvider().load(font.path).buffer.asByteData()).getFont(context)
            : () {
                print('Warning: "${font.path}" not found, falling back to Helvetica.');
                return pw.Font.helvetica().getFont(context);
              }(),
    };
  }
}
