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
  bool _paymentCompleted = false;
  bool _paymentSuccess = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            // Détecter les redirections de paiement réussi ou annulé
            if (request.url.contains('/payment/success') || request.url.contains('success=true')) {
              setState(() {
                _paymentCompleted = true;
                _paymentSuccess = true;
              });
              
              // Afficher l'overlay de succès pendant 2 secondes puis fermer la page
              Future.delayed(const Duration(seconds: 2), () {
                Navigator.pop(context, true); // Return true to indicate success
              });
              return NavigationDecision.prevent;
            } else if (request.url.contains('/payment/cancel') || request.url.contains('canceled=true')) {
              setState(() {
                _paymentCompleted = true;
                _paymentSuccess = false;
              });
              
              Future.delayed(const Duration(seconds: 2), () {
                Navigator.pop(context, false); // Return false to indicate cancellation
              });
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Confirmation avant de quitter le paiement
        if (!_paymentCompleted) {
          final shouldExit = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Annuler le paiement ?'),
              content: const Text('Êtes-vous sûr de vouloir annuler ce paiement ? Votre transaction ne sera pas traitée.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Non, continuer'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Oui, annuler'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
              ],
            ),
          ) ?? false;
          
          if (shouldExit) {
            return true;
          } else {
            return false;
          }
        }
        return true;
      },
      child: Stack(
        children: [
          Scaffold(
            appBar: AppBar(
              title: const Text("Paiement Stripe"),
              elevation: 0,
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
            ),
            body: WebViewWidget(controller: _controller),
          ),
          if (_paymentCompleted)
            Container(
              color: Colors.black54,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _paymentSuccess ? Icons.check_circle : Icons.cancel,
                        color: _paymentSuccess ? Colors.green : Colors.red,
                        size: 70,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _paymentSuccess 
                          ? 'Paiement réussi !' 
                          : 'Paiement annulé',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _paymentSuccess 
                          ? 'Merci pour votre achat. Vous allez être redirigé...' 
                          : 'Votre paiement a été annulé. Vous allez être redirigé...',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
