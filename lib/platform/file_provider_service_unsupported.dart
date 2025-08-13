import 'package:typesetting_prototype/platform/file_provider_interface.dart';

/// This is the fallback implementation for unsupported platforms.
FileProvider getFileProvider({String? basePath}) {
  throw UnsupportedError('Cannot create a FileProvider on this platform.');
}
