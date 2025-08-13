export 'file_provider_service_unsupported.dart'
    if (dart.library.io) 'file_provider_service_native.dart'
    if (dart.library.html) 'file_provider_service_web.dart';
