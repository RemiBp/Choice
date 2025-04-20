import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'register_user.dart';
import 'recover_producer.dart';
import 'login_user.dart'; // Importez la page de connexion

class LandingPage extends StatelessWidget {
  final Function toggleTheme;
  
  const LandingPage({Key? key, required this.toggleTheme}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('app_name'.tr()),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => RegisterUserPage()),
                );
              },
              child: Text('auth.register'.tr()),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => RecoverProducerPage()),
                );
              },
              child: Text('auth.recover'.tr()),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LoginUserPage()), // Redirige vers la page de connexion
                );
              },
              child: Text('auth.login'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
