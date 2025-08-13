import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:typesetting_prototype/typesetting_prototype.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:typesetting_prototype/platform/file_provider_service.dart';

sealed class ImageSource {
  const ImageSource();
}

class FileImageSource extends ImageSource {
  final String path;
  const FileImageSource(this.path);
}

class MemoryImageSource extends ImageSource {
  final Uint8List bytes;
  const MemoryImageSource(this.bytes);
}

class Image extends Widget {
  final ImageSource _source;
  final double? width;
  final double? height;

  const Image._(this._source, {this.width, this.height});

  factory Image.memory(Uint8List bytes, {double? width, double? height}) {
    return Image._(MemoryImageSource(bytes), width: width, height: height);
  }

  factory Image.file(String path, {double? width, double? height}) {
    return Image._(FileImageSource(path), width: width, height: height);
  }

  @override
  RenderNode createRenderNode() {
    return RenderImage(_source, width: width, height: height);
  }
}

class ImageManager {
  static PdfImage resolveImage(ImageSource source, pw.Context context) {
    return switch (source) {
      FileImageSource() => _resolveFileImage(source, context),
      MemoryImageSource() => _resolveMemoryImage(source, context),
    };
  }

  static PdfImage _resolveFileImage(FileImageSource source, pw.Context context) {
    final provider = getFileProvider();
    if (!provider.existsSync(source.path)) {
      throw Exception('Image file not found at path: ${source.path}');
    }
    final bytes = provider.load(source.path);
    return pw.MemoryImage(bytes).buildImage(context);
  }

  static PdfImage _resolveMemoryImage(MemoryImageSource source, pw.Context context) {
    return pw.MemoryImage(source.bytes).buildImage(context);
  }
}

class RenderImage extends RenderNode with RenderSlice {
  final ImageSource imageSource;
  final double? width;
  final double? height;

  PdfImage? _pdfImage;

  RenderImage(this.imageSource, {this.width, this.height});

  @override
  LayoutResult performLayout() {
    try {
      _pdfImage = ImageManager.resolveImage(imageSource, layoutContext!.pwContext);
    } catch (e) {
      print('⚠️ Image loading failed: $e');
      size = Size.zero;
      return LayoutResult.zero;
    }

    double finalWidth;
    double finalHeight;

    final imageAspectRatio = _pdfImage!.width / _pdfImage!.height;

    if (width != null && height != null) {
      finalWidth = width!;
      finalHeight = height!;
    } else if (width != null) {
      finalWidth = width!;
      finalHeight = finalWidth / imageAspectRatio;
    } else if (height != null) {
      finalHeight = height!;
      finalWidth = finalHeight * imageAspectRatio;
    } else {
      finalWidth = _pdfImage!.width.toDouble();
      finalHeight = _pdfImage!.height.toDouble();
    }

    size = constraints!.constrain(Size(finalWidth, finalHeight));
    return LayoutResult(size: size);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_pdfImage == null) return;

    context.canvas.drawImage(
      _pdfImage!,
      offset.dx,
      context.pageHeight - offset.dy - size.height,
      size.width,
      size.height,
    );
  }

  @override
  SliceLayoutResult layoutSlice(SliceLayoutContext context) {
    final layoutResult = layout(
      LayoutContext(pwContext: context.pwContext, constraints: context.constraints, metadata: context.metadata),
    );

    if (size.height <= context.availableHeight) {
      return SliceLayoutResult(
        paintedPrimitives: [PositionedPrimitive(this, Offset.zero)],
        consumedSize: size,
        remainder: null,
        metadata: layoutResult.metadata,
      );
    } else {
      return SliceLayoutResult(paintedPrimitives: [], consumedSize: Size.zero, remainder: this, metadata: []);
    }
  }
}
