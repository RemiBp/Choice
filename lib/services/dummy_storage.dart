class FlutterSecureStorage {
  Future<void> write({required String key, required String? value}) async {}
  Future<String?> read({required String key}) async => null;
  Future<void> delete({required String key}) async {}

  // ✅ Ajout d’un constructeur vide pour éviter les erreurs sur Web
  FlutterSecureStorage();
}
