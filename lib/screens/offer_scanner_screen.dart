import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class OfferScannerScreen extends StatefulWidget {
  const OfferScannerScreen({super.key});

  @override
  State<OfferScannerScreen> createState() => _OfferScannerScreenState();
}

class _OfferScannerScreenState extends State<OfferScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    // Optional: Configure detection speed, torch, camera facing, etc.
    // detectionSpeed: DetectionSpeed.normal,
    // facing: CameraFacing.back,
    // torchEnabled: false,
  );
  bool _isProcessing = false; // Prevent multiple detections at once

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scanner le QR Code de l\'Offre')),
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: (capture) {
              if (_isProcessing) return;
              setState(() { _isProcessing = true; });

              final List<Barcode> barcodes = capture.barcodes;
              // final Uint8List? image = capture.image; // You can use the image if needed

              if (barcodes.isNotEmpty) {
                final String? scannedCode = barcodes.first.rawValue;
                print(' Scanned Raw Value: $scannedCode');

                if (scannedCode != null && scannedCode.isNotEmpty) {
                  // Stop the camera and pop the screen, returning the code
                  _scannerController.stop();
                  Navigator.pop(context, scannedCode); // Return the scanned code
                } else {
                  // Handle empty scan result
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('QR Code non reconnu.'), backgroundColor: Colors.orange),
                  );
                  // Resume scanning after a short delay
                  Future.delayed(const Duration(seconds: 2), () {
                    if (mounted) setState(() => _isProcessing = false);
                  });
                }
              } else {
                 // No barcode detected in this frame
                 setState(() => _isProcessing = false);
              }
            },
          ),
          // Optional: Add an overlay with a scanning area indicator
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.red, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          )
        ],
      ),
    );
  }
} 