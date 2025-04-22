import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class MyOffersScreen extends StatelessWidget {
  const MyOffersScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('my_offers_screen.app_bar_title'.tr()),
      ),
      body: Center(
        child: Text(
          'my_offers_screen.coming_soon'.tr(), // Placeholder text
          style: Theme.of(context).textTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
} 