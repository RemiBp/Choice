import 'package:flutter/material.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({Key? key}) : super(key: key);

  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  String _preferences = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifier le Profil'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                initialValue: 'Nom actuel',
                decoration: const InputDecoration(labelText: 'Nom'),
                onSaved: (value) => _name = value!,
              ),
              TextFormField(
                initialValue: 'Préférences actuelles',
                decoration: const InputDecoration(labelText: 'Préférences'),
                onSaved: (value) => _preferences = value!,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    _formKey.currentState!.save();
                    // Appeler une API pour sauvegarder les modifications
                  }
                },
                child: const Text('Sauvegarder'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
