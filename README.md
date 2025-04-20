# choice_app_new

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Description
Choice App est une application mobile qui permet aux utilisateurs de découvrir et d'interagir avec des restaurants, des lieux de loisirs et de bien-être.

## Configuration de l'environnement

### Variables d'environnement

Pour le développement local, créez un fichier `.env` à la racine du projet avec les variables suivantes :

```
# Configuration de l'API
API_BASE_URL=https://api.choiceapp.fr
WEBSOCKET_URL=wss://api.choiceapp.fr

# Clés d'API externes
GOOGLE_MAPS_API_KEY=votre_clé_google_maps
STRIPE_SECRET_KEY=votre_clé_stripe_secrète
STRIPE_WEBHOOK_SECRET=votre_clé_webhook_stripe
OPENAI_API_KEY=votre_clé_openai

# Configuration du serveur (utilisé principalement par le backend)
MONGO_URI=votre_uri_mongo
JWT_SECRET=votre_secret_jwt
```

**Note importante :** Le fichier `.env` est dans `.gitignore` et ne doit jamais être commité sur GitHub.

### Configuration pour Codemagic (CI/CD)

Pour les builds automatisés sur Codemagic :

1. Ajoutez un groupe d'environnement nommé `choice_app_env` dans les paramètres Codemagic.
2. Configurez les variables suivantes dans ce groupe :
   - `CM_GOOGLE_MAPS_API_KEY`
   - `CM_MONGO_URI`
   - `CM_JWT_SECRET`
   - `CM_STRIPE_SECRET_KEY`
   - `CM_STRIPE_WEBHOOK_SECRET`
   - `CM_OPENAI_API_KEY`

Le fichier `codemagic.yaml` contient déjà la configuration nécessaire pour créer automatiquement un fichier `.env` lors du build.

## Lancement de l'application

Pour lancer l'application en mode développement :

```bash
flutter pub get
flutter run
```

## Mise en production

Les builds sont gérés par Codemagic CI/CD :
- La branche `main` déclenche automatiquement un build Android et iOS.
- Les artefacts sont envoyés par email aux destinataires configurés.
