import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebViewStripePage extends StatefulWidget {
  final String url;

  const WebViewStripePage({Key? key, required this.url}) : super(key: key);

  @override
  _WebViewStripePageState createState() => _WebViewStripePageState();
}

class _WebViewStripePageState extends State<WebViewStripePage> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Paiement Stripe")),
      body: WebViewWidget(controller: _controller),
    );
  }
}
