import 'dart:io';
import 'dart:typed_data';
import 'file_provider_interface.dart';

/// Concrete implementation for native platforms.
class _NativeFileProvider implements FileProvider {
  final String _basePath;

  _NativeFileProvider({String basePath = ''}) : _basePath = basePath;

  @override
  Uint8List load(String path) {
    final fullPath = _basePath.isEmpty ? path : '$_basePath/$path';
    return File(fullPath).readAsBytesSync();
  }

  @override
  bool existsSync(String path) {
    final fullPath = _basePath.isEmpty ? path : '$_basePath/$path';
    return File(fullPath).existsSync();
  }
}

/// This implementation is chosen when compiling for native platforms.
FileProvider getFileProvider({String? basePath}) {
  return _NativeFileProvider(basePath: basePath ?? '');
}
