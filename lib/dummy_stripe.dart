// This is a dummy implementation of Stripe for web platforms
// It will be imported under the 'stripe_pkg' namespace in main.dart
class Stripe {
  static String publishableKey = "";
  static final instance = Stripe();

  Future<void> applySettings() async {
    print("⚠️ Stripe non supporté sur Web, fallback activé.");
  }
}
