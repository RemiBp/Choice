import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class StripeCheckoutPage extends StatefulWidget {
  final String url;

  const StripeCheckoutPage({Key? key, required this.url}) : super(key: key);

  @override
  _StripeCheckoutPageState createState() => _StripeCheckoutPageState();
}

class _StripeCheckoutPageState extends State<StripeCheckoutPage> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _controller = WebViewController();
      _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      _controller.loadRequest(Uri.parse(widget.url));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      // Sur Web, on ouvre Stripe dans un nouvel onglet
      launchUrl(Uri.parse(widget.url), mode: LaunchMode.externalApplication);
      Navigator.pop(context); // Ferme la page après redirection
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    } else {
      return Scaffold(
        appBar: AppBar(title: const Text("Paiement Stripe")),
        body: WebViewWidget(controller: _controller),
      );
    }
  }
}
