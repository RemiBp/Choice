# Choice App Feed Enhancement & Auto Post Generation

Ce projet améliore le feed de l'application Choice et implémente un système de génération automatique de posts en s'appuyant sur DeepSeek.

## Vue d'ensemble

### Problématiques adressées

1. **Amélioration de l'algorithme du feed** pour le rendre plus pertinent et personnalisé en fonction :
   - Des intérêts des utilisateurs
   - De leur localisation
   - De leurs relations sociales (following/followers)
   - De leurs interactions précédentes

2. **Génération automatique de posts** pour :
   - Créer de l'engagement avant que les producteurs ne prennent en main leur compte
   - Générer du contenu pertinent et engageant basé sur les événements à venir
   - Adapter les posts au profil et à la localisation des utilisateurs
   - Permettre aux producteurs de contrôler la génération automatique

## Fichiers implémentés

### 1. `feed_enhancement_proposal.md`

Document détaillant l'analyse de l'existant et les améliorations proposées :
- Analyse de l'algorithme de feed actuel
- Stratégie d'amélioration avec exemples de code
- Approche pour la génération automatique de posts
- Plan d'implémentation et d'intégration

### 2. `auto_post_generator.js`

Implémentation du générateur automatique de posts utilisant DeepSeek :
- Génération de posts pour les événements à venir
- Génération de posts pour les producteurs (restaurants, lieux de loisir)
- Génération de posts de découverte basés sur les intérêts des utilisateurs
- Prompts optimisés pour différents styles et contextes
- Gestion d'erreur et stratégies de repli

### 3. `post_automation_integration.js`

Intégration de l'automatisation et de l'algorithme amélioré avec le backend :
- Planification des tâches de génération via cron
- Routes pour le contrôle manuel et les paramètres des producteurs
- Implémentation de l'algorithme de feed amélioré
- Mécanismes de diversification du contenu et d'équilibrage

## Comment l'implémenter

### Prérequis

1. Accès à un serveur DeepSeek (sur vast.ai comme mentionné dans la tâche)
2. Configuration des variables d'environnement :
   ```
   DEEPSEEK_SERVER_URL=http://your-vast-ai-server:8000/generate
   DEEPSEEK_API_KEY=your_api_key
   ```

### Étapes d'intégration

1. **Dans le backend (index.js)**

Ajouter l'intégration :

```javascript
const { integrateWithApp } = require('./path/to/post_automation_integration');

// Après avoir initialisé votre application Express
const app = express();
// ... configuration de l'app ...

// Intégrer l'automatisation des posts
integrateWithApp(app);
```

2. **Créer un modèle pour les paramètres d'auto-post des producteurs**

```javascript
// Schema for auto_post_settings in Producer model
auto_post_settings: {
  enabled: { type: Boolean, default: false },
  frequency: { type: String, enum: ['daily', 'weekly', 'biweekly'], default: 'weekly' },
  focus_areas: { type: [String], default: ['menu', 'events', 'promotions'] },
  tone: { type: String, enum: ['professional', 'casual', 'enthusiastic', 'elegant', 'humorous'], default: 'professional' }
}
```

3. **Ajouter les routes frontend pour les paramètres des producteurs**

Créer des interfaces pour permettre aux producteurs de contrôler :
- L'activation/désactivation des posts automatiques
- La fréquence des posts
- Les domaines d'intérêt à mettre en avant
- Le ton des posts

4. **Mettre à jour les modèles de données**

Ajouter les champs nécessaires pour suivre les métriques d'engagement et les préférences utilisateur qui alimentent l'algorithme amélioré.

## Comment ça répond aux besoins

### 1. Feed personnalisé basé sur le profil utilisateur

L'algorithme amélioré prend en compte :
- Les tags/intérêts explicites des utilisateurs
- Leurs interactions passées (likes, choices, comments)
- Leurs connexions sociales (following/followers)
- Leur localisation et lieux fréquents
- Le contexte temporel (jour, heure)

### 2. Génération de posts engageants et variés

Le système génère automatiquement :
- **Posts d'événements** : Promotion des événements à venir adaptée aux préférences utilisateur
- **Posts de producteurs** : Mise en avant des spécialités, menus ou ambiance des restaurants/lieux
- **Posts de découverte** : Recommandations personnalisées basées sur les intérêts

### 3. Contrôle pour les producteurs

Les producteurs peuvent :
- Activer/désactiver la génération automatique
- Choisir la fréquence des posts
- Définir les aspects à mettre en avant
- Sélectionner le ton des communications

### 4. Diversité du contenu

Le système garantit un feed équilibré et engageant grâce à :
- Redistribution intelligente des types de contenu
- Diversification des styles de posts
- Adaptation au contexte temporel
- Équilibre entre contenu familier et découverte

## Exemple d'intégration avec DeepSeek

Le système utilise des prompts sophistiqués pour générer des posts naturels et engageants. Exemple pour un événement :

```javascript
// Extrait du code de génération de prompt
const prompt = `
Écris un post engageant pour un réseau social à propos de cet événement.

DÉTAILS DE L'ÉVÉNEMENT:
Nom: ${event.name}
Lieu: ${event.venue}
Date: ${event.date}
Catégorie: ${event.category}
Description: ${event.description}
Prix: ${event.price}

PUBLIC CIBLE:
Intérêts: ${interestList}
Localisation: ${audience?.location || 'Paris'}
${demographicsText}

STYLE DU POST: ${style}

EXEMPLE DE CE STYLE:
"${styleExample}"

INSTRUCTIONS:
- Le post doit être écrit en français
- Ton conversationnel et authentique
- Entre 30 et 60 mots
- Ne pas utiliser d'émojis ni de hashtags
- Créer un sentiment de FOMO (peur de manquer quelque chose)

IMPORTANT: Réponds uniquement avec le texte du post.
`;
```

## Test et optimisation

1. **Phase initiale** : Déployer avec surveillance étroite des métriques d'engagement
2. **Optimisation des prompts** : Affiner selon les performances des différents styles
3. **Ajustement de l'algorithme** : Calibrer les poids des différents facteurs de pertinence
4. **A/B testing** : Comparer différentes stratégies de diversification

## Conclusion

Cette implémentation permet de créer un feed dynamique et personnalisé tout en générant automatiquement du contenu engageant adapté aux intérêts des utilisateurs. Le système s'appuie sur les données existantes (posts, événements, producteurs) et les enrichit avec une couche d'intelligence artificielle pour stimuler l'engagement et combler le vide initial de contenu.