import 'dart:typed_data';

/// An abstract interface for loading binary assets from a given path.
/// This allows the core library to be platform-agnostic.
abstract class FileProvider {
  Uint8List load(String path);
  bool existsSync(String path);
}
