// screens/utils.dart (Gestion des imports conditionnels)
export 'utils_stub.dart'
  if (dart.library.io) 'utils_io.dart'
  if (dart.library.html) 'utils_web.dart';