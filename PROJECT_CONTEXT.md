# Choice App - Contexte du Projet

## Vue d'ensemble
Choice App est une plateforme sociale innovante qui connecte les utilisateurs avec différents types de producteurs locaux (restauration, loisirs, bien-être). L'application offre une expérience personnalisée permettant aux utilisateurs de découvrir des établissements selon leurs préférences, de suivre leurs activités, d'interagir avec eux via messagerie, et de partager leurs expériences avec leur réseau.

Pour les professionnels (producteurs), l'application fournit un écosystème complet pour développer leur activité, communiquer avec leur clientèle, et analyser leur performance via des tableaux de bord dédiés.

## Types d'utilisateurs
1. **Utilisateurs standard**
   - Peuvent découvrir et suivre des producteurs locaux
   - Partagent leurs expériences via des posts et commentaires
   - Interagissent avec leur réseau social et les producteurs
   - Reçoivent des recommandations personnalisées

2. **Producteurs de restauration**
   - Restaurants, cafés, bars, food trucks, traiteurs
   - Publient leur menu, offres spéciales, et événements
   - Analysent leur audience et performance
   - Identifiés par la couleur ORANGE dans l'application

3. **Producteurs de loisirs**
   - Activités culturelles, sportives, événementielles
   - Attractions touristiques, parcs, cinémas, théâtres
   - Gèrent leurs événements et billets
   - Identifiés par la couleur VIOLET dans l'application

4. **Producteurs de bien-être**
   - Spas, salons de beauté, centres de fitness
   - Praticiens de santé alternative, yoga, méditation
   - Gèrent leurs rendez-vous et services
   - Identifiés par la couleur VERT dans l'application

## Architecture technique

### Frontend
- **Framework**: Flutter (pour développement cross-platform)
- **État**: Provider pour la gestion d'état
- **UI/UX**: Design system cohérent avec thèmes adaptés par type d'utilisateur
- **Navigation**: Structure à onglets avec navigation contextuelle
- **Cartographie**: Integration Google Maps avec clusters et filtres
- **Messagerie**: Système de chat temps réel

### Backend
- **Serveur**: Node.js avec Express
- **API**: REST API avec documentation OpenAPI/Swagger
- **Authentification**: JWT avec refresh tokens et sécurité renforcée
- **Validation**: Middleware pour validation des données entrantes
- **Logging**: Winston pour journalisation structurée

### Base de données
- **Principale**: MongoDB (NoSQL)
- **Structure**: Collections séparées pour utilisateurs, producteurs (par type), posts, messages
- **Relations**: Utilisation de références et d'agrégations
- **Indexation**: Optimisée pour les requêtes géospatiales et la recherche full-text
- **Performances**: Caching avec Redis pour les données fréquemment accédées

### Cloud & Services tiers
- **Firebase**: 
  - FCM pour les notifications push
  - Firebase Storage pour les médias
  - Analytics pour les métriques d'utilisation
- **Google Cloud Platform**:
  - Google Maps API pour la cartographie
  - Cloud Functions pour traitements asynchrones
- **Stockage médias**: Optimisation et CDN pour images et vidéos

## Relations MongoDB => Backend => Frontend

### Structure MongoDB
L'application utilise 4 bases de données principales dans MongoDB Atlas:

1. **choice_app**
   - Collections principales: users, conversations, messages, posts, follows, likes
   - Stocke toutes les données transversales et interactions entre utilisateurs

2. **Restauration_Officielle**
   - Collections principales: producers, menus, specialties
   - Stocke les données spécifiques aux producteurs de restauration

3. **Loisir&Culture**
   - Collections principales: leisureProducers, events, activities
   - Stocke les données spécifiques aux producteurs de loisirs

4. **Beauty_Wellness**
   - Collections principales: wellnessProducers, services, practitioners
   - Stocke les données spécifiques aux producteurs de bien-être

### Flux de données typiques

#### 1. Flux de messagerie
**MongoDB** → **Backend** → **Frontend**
- **MongoDB**: Les conversations sont stockées dans `choice_app.conversations` avec références aux participants
- **Backend**: Route `/api/conversations/:userId` récupère avec agrégation toutes les conversations
- **Frontend**: `MessagingScreen` ou `ProducerMessagingScreen` affiche les conversations selon le type d'utilisateur

#### 2. Flux de feed
**MongoDB** → **Backend** → **Frontend**
- **MongoDB**: Posts stockés dans `choice_app.posts` avec références aux auteurs
- **Backend**: Route `/api/feed/:userId` récupère et filtre les posts pertinents
- **Frontend**: `FeedScreen` ou `ProducerFeedScreen` affiche le contenu avec UI adaptée

#### 3. Flux de cartographie
**MongoDB** → **Backend** → **Frontend**
- **MongoDB**: Producteurs avec coordonnées géospatiales dans leurs bases respectives
- **Backend**: Routes `/api/map/nearby` avec requêtes géospatiales optimisées
- **Frontend**: `MapScreen` intègre Google Maps et affiche les marqueurs avec clusters

#### 4. Flux de notifications
**Backend** → **Firebase** → **Frontend**
- **Backend**: Détecte événements (nouveau message, mention) et prépare notifications
- **Firebase**: FCM achemine les notifications aux appareils des utilisateurs
- **Frontend**: `NotificationService` gère l'affichage et les interactions

### Optimisations clés
1. **Indexation MongoDB**:
   - Index géospatiaux pour recherches de proximité
   - Index composites pour requêtes d'agrégation complexes
   - Index textuels pour recherche full-text optimisée

2. **Caching Backend**:
   - Mise en cache des requêtes fréquentes (listes de producteurs, conversations)
   - Invalidation sélective sur modifications
   - Compression des réponses pour réduire la bande passante

3. **Performance Frontend**:
   - Chargement paresseux (lazy loading) des assets et médias
   - Pagination pour les grands volumes de données
   - Stockage local des données fréquemment accédées

## Modèle de données

### Utilisateurs
```json
{
  "_id": "ObjectId",
  "username": "string",
  "email": "string",
  "passwordHash": "string",
  "profilePicture": "url",
  "bio": "string",
  "location": {
    "type": "Point",
    "coordinates": [longitude, latitude]
  },
  "preferences": {
    "cuisineTypes": ["string"],
    "activityTypes": ["string"],
    "maxDistance": "number"
  },
  "following": ["producerId"],
  "followers": ["userId"],
  "favorites": ["producerId"],
  "createdAt": "date",
  "lastActive": "date",
  "fcmToken": "string"
}
```

### Producteurs (structure de base)
```json
{
  "_id": "ObjectId",
  "type": "string (restaurant|leisureProducer|wellnessProducer)",
  "businessName": "string",
  "description": "string",
  "contactInfo": {
    "email": "string",
    "phone": "string",
    "website": "string"
  },
  "location": {
    "address": "string",
    "city": "string",
    "postalCode": "string",
    "coordinates": {
      "type": "Point",
      "coordinates": [longitude, latitude]
    }
  },
  "businessHours": [{
    "day": "number",
    "open": "string",
    "close": "string",
    "isClosed": "boolean"
  }],
  "photos": ["url"],
  "coverImage": "url",
  "logo": "url",
  "followers": ["userId"],
  "rating": "number",
  "reviewsCount": "number",
  "tags": ["string"],
  "createdAt": "date",
  "fcmToken": "string"
}
```

### Posts
```json
{
  "_id": "ObjectId",
  "authorId": "string",
  "authorType": "string (user|producer)",
  "content": "string",
  "media": [{
    "type": "string (image|video)",
    "url": "string",
    "thumbnail": "string"
  }],
  "location": {
    "type": "Point",
    "coordinates": [longitude, latitude],
    "placeName": "string"
  },
  "tags": ["string"],
  "mentions": ["userId"],
  "likes": ["userId"],
  "commentsCount": "number",
  "visibility": "string (public|followers|private)",
  "createdAt": "date"
}
```

### Conversations
```json
{
  "_id": "ObjectId",
  "type": "string (individual|group)",
  "participants": ["userId or producerId"],
  "groupName": "string (for group chats)",
  "groupAvatar": "url (for group chats)",
  "createdAt": "date",
  "lastMessageAt": "date",
  "lastMessage": {
    "senderId": "string",
    "content": "string",
    "timestamp": "date",
    "readBy": ["participantId"]
  }
}
```

### Messages
```json
{
  "_id": "ObjectId",
  "conversationId": "string",
  "senderId": "string",
  "senderType": "string (user|producer)",
  "content": "string",
  "mediaUrl": "string",
  "mediaType": "string",
  "timestamp": "date",
  "status": "string (sent|delivered|read)",
  "readBy": ["participantId"]
}
```

## Fonctionnalités principales

### 1. Système de Feed
- **Feed personnalisé** basé sur les préférences et l'historique
- **Algorithme de recommandation** priorisant les producteurs pertinents
- **Contenu dynamique** mêlant posts, événements et promotions
- **Filtres contextuels** permettant d'affiner l'expérience
- **Pull-to-refresh** et chargement pagination infinie

### 2. Système de Cartographie
- **Cartes interactives** montrant les producteurs à proximité
- **Filtres multiples** par type, distance, note, prix
- **Clustering** pour zones à forte densité
- **Animations fluides** lors des déplacements sur la carte
- **Détail au survol/tap** avec aperçu rapide
- **Mode heatmap** pour les producteurs visualisant l'activité utilisateur

### 3. Messagerie
- **Conversations individuelles** entre utilisateurs et producteurs
- **Conversations de groupe** pour planifier des activités collectives
- **Support multimédia** (texte, images, emojis)
- **Statut de lecture** et indicateurs de frappe
- **Notifications push** pour nouveaux messages
- **Interface adaptative** selon le type de producteur
- **Catégorisation des conversations** pour les producteurs (clients, autres producteurs du même type, etc.)

### 4. Système de Recherche
- **Recherche full-text** avec suggestions intelligentes
- **Filtres avancés** par catégorie, distance, popularité
- **Recherche géolocalisée** adaptée à la position de l'utilisateur
- **Historique de recherche** pour accès rapide aux requêtes précédentes
- **Tags et catégories** pour affiner les résultats

### 5. Profils
- **Profils utilisateurs** avec photos, bio, producteurs suivis
- **Profils producteurs** personnalisés selon leur catégorie
  - **Restaurants**: menu, spécialités, horaires
  - **Loisirs**: événements, activités, calendrier
  - **Bien-être**: services, rendez-vous, praticiens
- **Gallerie médias** montrant les photos et posts
- **Statistiques d'engagement** visibles par les producteurs

### 6. Tableaux de bord analytiques
- **Vue d'ensemble** avec métriques clés (visiteurs, engagement)
- **Analyse démographique** des followers et clients
- **Statistiques de performance** des publications et promotions
- **Heatmaps** montrant l'activité des utilisateurs par zone
- **Rapports d'engagement** avec graphiques interactifs
- **Prédictions et tendances** basées sur l'IA

### 7. Système de notifications
- **Notifications push** pour nouveaux messages, mentions, événements
- **Notifications in-app** pour activité dans l'application
- **Paramètres de préférence** permettant de filtrer les notifications
- **Badge d'application** indiquant le nombre de notifications non lues
- **Centre de notifications** centralisant toutes les alertes

## Exemples de routes API

### Authentification
- `POST /api/auth/login` - Connexion utilisateur/producteur
- `POST /api/auth/register` - Inscription utilisateur
- `POST /api/auth/refresh` - Rafraîchir le token JWT

### Utilisateurs
- `GET /api/users/:userId` - Récupérer profil utilisateur
- `GET /api/users/:userId/following` - Producteurs suivis
- `POST /api/users/:userId/follow/:producerId` - Suivre un producteur

### Producteurs
- `GET /api/producers/:producerId` - Profil producteur (restauration)
- `GET /api/leisureProducers/:producerId` - Profil producteur (loisir)
- `GET /api/wellnessProducers/:producerId` - Profil producteur (bien-être)
- `GET /api/producers/nearby` - Producteurs à proximité (géospatial)

### Feed
- `GET /api/feed/:userId` - Récupérer feed personnalisé
- `GET /api/producer-feed/:producerId` - Feed spécifique producteur

### Messagerie
- `GET /api/conversations/:userId` - Conversations utilisateur
- `GET /api/conversations/:producerId/producer-conversations` - Conversations producteur
- `POST /api/messages` - Envoyer un message
- `GET /api/messages/:conversationId` - Historique des messages

### Recherche
- `GET /api/search?query=...` - Recherche globale
- `GET /api/producers/search?type=restaurant&query=...` - Recherche producteurs par type

## Flux utilisateur

### Utilisateur standard
1. S'inscrit et complète son profil avec ses préférences
2. Explore la carte des producteurs à proximité
3. Suit des producteurs qui l'intéressent
4. Reçoit du contenu personnalisé dans son feed
5. Interagit avec les publications (likes, commentaires)
6. Échange des messages avec producteurs et autres utilisateurs
7. Partage ses expériences via des posts
8. Reçoit des notifications pour les nouveaux événements

### Producteur
1. Crée et configure son profil professionnel
2. Publie du contenu (offres, événements, actualités)
3. Analyse son audience et ses performances
4. Répond aux messages des clients
5. Gère ses groupes de discussion
6. Organise sa communication par catégories de contacts
7. Consulte les heatmaps pour comprendre les comportements utilisateurs
8. Adapte sa stratégie selon les analyses

## Identité visuelle
- **Restauration** (ORANGE): 
  - Couleur primaire: #FF9800
  - Icône: restaurant/food
  - Ambiance: chaleureuse et appétissante
  
- **Loisirs** (VIOLET): 
  - Couleur primaire: #9C27B0
  - Icône: event/activity
  - Ambiance: dynamique et divertissante
  
- **Bien-être** (VERT): 
  - Couleur primaire: #4CAF50
  - Icône: spa/wellness
  - Ambiance: apaisante et ressourçante
  
- **Utilisateurs** (BLEU): 
  - Couleur primaire: #2196F3
  - Icône: person
  - Ambiance: sociale et connectée

## Défis techniques
- **Performances de la carte** avec nombreux marqueurs
- **Synchronisation en temps réel** des messages
- **Optimisation des requêtes géospatiales**
- **Gestion de la batterie** et des ressources mobiles
- **Adaptation cross-platform** pour une expérience cohérente
- **Scalabilité** pour supporter la croissance des utilisateurs

## Fonctionnalités en développement
- **Amélioration du système de messagerie pour les producteurs**
  - Interface personnalisée par type de producteur
  - Catégorisation des conversations
  - Templates de réponses rapides
  - Statistiques d'engagement client
  
- **Personnalisation des interfaces selon le type de producteur**
  - Codes couleur distincts
  - Fonctionnalités spécifiques à chaque métier
  - Tableaux de bord adaptés
  
- **Optimisation des notifications en temps réel**
  - Réduction de la latence
  - Contenus riches (images, actions)
  - Gestion intelligente des priorités
  
- **Intégration de fonctionnalités de paiement**
  - Réservations et commandes in-app
  - Portefeuille électronique
  - Historique de transactions
  
- **Amélioration des recommandations basées sur l'IA**
  - Apprentissage des préférences utilisateur
  - Suggestions contextuelles (heure, lieu, météo)
  - Prédiction des tendances 