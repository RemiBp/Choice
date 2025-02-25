class Stripe {
  static String publishableKey = "";
  static final instance = Stripe();

  Future<void> applySettings() async {
    print("⚠️ Stripe non supporté sur Web, fallback activé.");
  }
}
