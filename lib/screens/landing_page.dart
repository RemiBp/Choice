import 'package:flutter/material.dart';
import 'register_user.dart';
import 'recover_producer.dart';
import 'login_user.dart'; // Importez la page de connexion

class LandingPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Choice App'),
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
              child: Text('Créer un compte utilisateur'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => RecoverProducerPage()),
                );
              },
              child: Text('Récupérer un compte producer'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LoginUserPage()), // Redirige vers la page de connexion
                );
              },
              child: Text('Se connecter'),
            ),
          ],
        ),
      ),
    );
  }
}
