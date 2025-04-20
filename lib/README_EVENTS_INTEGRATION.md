# Intégration des Événements et du Calendrier

Ce document explique l'intégration entre le système d'événements existant pour les producteurs de loisir et la nouvelle fonctionnalité de calendrier d'événements.

## Architecture de l'intégration

### 1. Services et Modèles

- **EventCalendarService**: Service central pour la gestion des événements avec table_calendar
  - Convertit les événements existants de loisir via `convertLeisureEventToCalendarEvent()`
  - Utilise `CalendarEvent` de calendar_service.dart comme modèle

- **AnalyticsService**: Service d'analyse qui suit les interactions utilisateur
  - Intégré à toutes les vues d'événements pour le tracking des interactions

### 2. Écrans et Widgets

- **EventCalendarWidget**: Widget réutilisable qui affiche les événements dans un calendrier
  - Utilise table_calendar pour l'affichage
  - Compatible avec les événements de tous types de producteurs

- **LeisureEventsCalendarScreen**: Écran combiné qui affiche:
  - Une vue calendrier (onglet 1)
  - Une liste d'événements traditionnelle (onglet 2)
  - Dirige vers EventLeisureScreen pour les détails

- **EventDetailsScreen**: Vue générique des détails d'événement
  - Redirige automatiquement vers EventLeisureScreen pour les événements de loisir
  - Contient les fonctionnalités communes (ajout au calendrier, partage)

- **EventLeisureScreen**: Vue détaillée existante des événements de loisir (inchangée)
  - Préservée pour sa richesse fonctionnelle (lineup, prix, notes, etc.)

## Flux Utilisateur

1. L'utilisateur accède à la page d'un producteur de loisir
2. Il peut voir les événements listés comme avant
3. Nouveau bouton "Voir le calendrier des événements" lui permet d'accéder à la vue calendrier
4. Dans la vue calendrier, il peut:
   - Naviguer entre les mois/semaines
   - Sélectionner un jour pour voir les événements correspondants
   - Taper sur un événement pour voir ses détails
5. Les détails s'affichent dans EventLeisureScreen avec toutes les fonctionnalités existantes

## Avantages de cette Approche

1. **Préservation des fonctionnalités riches**: Maintient toutes les fonctionnalités avancées de la vue événement existante
2. **Vue calendrier intuitive**: Ajoute une nouvelle façon de visualiser les événements
3. **Tracking Analytics**: Intègre le suivi des interactions utilisateur pour l'analyse
4. **Structure modulaire**: Permet de réutiliser les composants dans différents contextes

## Points à Compléter

1. Modifier les écrans existants qui listent des événements pour ajouter l'option de vue calendrier
2. Ajouter un écran de calendrier général pour tous les événements (toutes catégories)
3. Implémenter le filtrage dans la vue calendrier

## Comment Utiliser

Pour ajouter le calendrier à un écran existant:

```dart
// Importer les fichiers nécessaires
import '../widgets/event_calendar_widget.dart';
import '../services/event_calendar_service.dart';

// Utiliser le widget dans votre UI
EventCalendarWidget(
  producerId: 'ID_PRODUCTEUR', // Optionnel, pour filtrer les événements d'un producteur
  showAllEvents: true, // Pour afficher tous les événements
  onEventTap: (event) {
    // Action lors du tap sur un événement
  },
)
```

Pour convertir des événements existants pour le calendrier:

```dart
// Récupérer les événements depuis l'API
final events = await fetchEvents();

// Convertir et ajouter au service de calendrier
eventCalendarService.addLeisureEvents(events);
``` 