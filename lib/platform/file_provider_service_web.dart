import 'dart:typed_data';
import 'file_provider_interface.dart';

/// Concrete implementation for web platforms.
class _WebFileProvider implements FileProvider {
  const _WebFileProvider();

  @override
  Uint8List load(String path) {
    //TODO: implement paths for web
    throw UnsupportedError(
      'Synchronous font loading from path "$path" is not supported on the web. '
      'Fonts must be pre-loaded.',
    );
  }

  @override
  bool existsSync(String path) {
    // This is impossible to check synchronously on the web.
    return true;
  }
}

/// This implementation is chosen when compiling for the web.
FileProvider getFileProvider({String? basePath}) {
  return const _WebFileProvider();
}
