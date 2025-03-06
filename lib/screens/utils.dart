// screens/utils.dart (Gestion des imports conditionnels)
// Properly handle platform-specific exports with mutual exclusion
// When compiling for web, only utils_web.dart should be included
// When compiling for mobile/desktop, only utils_io.dart should be included
export 'utils_stub.dart'
    if (dart.library.html) 'utils_web.dart'
    if (dart.library.io) 'utils_io.dart';