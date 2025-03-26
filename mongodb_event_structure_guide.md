# Guide de Structures MongoDB pour la Génération de Posts

Ce document explique les différentes structures MongoDB pour les événements et les producteurs dans l'application Choice. Il est crucial pour le système de génération automatique de posts de comprendre ces structures pour créer des contenus pertinents qui respectent strictement les données réelles.

## Formats de Date et Vérification des Événements Passés

Une partie critique du processus est de vérifier si un événement est déjà terminé pour éviter de générer des posts pour des événements passés.

### Structures de Dates dans Loisir&Culture

```javascript
// Format typique des événements dans Loisir&Culture
{
  _id: "676d7734bc725bb6e91c51e3",
  intitulé: "Donnez moi un coupable au hasard",
  catégorie: "Théâtre » Comédie » Comédie satirique à partir de 15 ans",
  détail: "Comédie féroce et cash Avec Gwendal Anglade, Claire Chastel, Pierre…",
  lieu: "Les 3T - Théâtre du Troisième Type",
  // Dates au format français
  date_debut: "25/01/2025",
  date_fin: "02/02/2025",
  // Structure pour les horaires
  horaires: [
    {
      jour: "ven",
      heure: "20:30"
    },
    {
      jour: "sam",
      heure: "20:30"
    }
  ]
}

// Format alternatif avec prochaines_dates
{
  _id: "67a0d1733a2fc0b65e5c9d15",
  intitulé: "Dylan Dylan Residency : Otik (+) Goldie B B2b Pura Pura",
  catégorie: "house",
  détail: "📍 Samedi 15 février - 23h30/07h00\n\nClub - Dylan Dylan residency : Oti…",
  lieu: "BADABOUM",
  // Format texte pour dates prochaines
  prochaines_dates: "sam 15 févr.",
  // Format alternatif pour horaires
  horaires: [
    {
      jour: "sam",
      heure: "23:30 - 07:00"
    }
  ],
  // Structure pour lineup d'artistes
  lineup: [
    {
      nom: "Otik",
      image: "https://res.cloudinary.com/shotgun/image/upload/c_limit,w_750/fl_lossy…"
    },
    // Plus d'artistes...
  ]
}
```

### Code pour Vérifier les Dates des Événements

```javascript
// Fonction pour parser différents formats de date
function parseEventDate(dateStr) {
  if (!dateStr) return new Date(); // Default to today if no date
  
  // Format: DD/MM/YYYY
  if (dateStr.includes('/')) {
    const [day, month, year] = dateStr.split('/').map(part => parseInt(part, 10));
    return new Date(year, month - 1, day);
  }
  
  // Try standard Date parsing for ISO formats
  return new Date(dateStr);
}

// Fonction pour parser les dates depuis horaires
function parseEventDateFromHoraires(horaire, prochaines_dates) {
  // Handle date from prochaines_dates like "sam 15 févr."
  if (prochaines_dates) {
    const months = {
      'janv': 0, 'févr': 1, 'mars': 2, 'avr': 3, 'mai': 4, 'juin': 5,
      'juil': 6, 'août': 7, 'sept': 8, 'oct': 9, 'nov': 10, 'déc': 11
    };
    
    const parts = prochaines_dates.split(' ');
    if (parts.length >= 3) {
      const day = parseInt(parts[1], 10);
      const monthStr = parts[2].replace('.', '');
      const month = months[monthStr];
      
      if (!isNaN(day) && month !== undefined) {
        const year = new Date().getFullYear();
        return new Date(year, month, day);
      }
    }
  }
  
  // Default to today
  return new Date();
}

// Vérifier si un événement est déjà terminé
function isEventPassed(event) {
  const today = new Date();
  
  // Get event end date using various possible structures
  const eventEndDate = event.date_fin 
    ? parseEventDate(event.date_fin) 
    : (event.horaires && event.horaires.length > 0
        ? parseEventDateFromHoraires(event.horaires[0], event.prochaines_dates)
        : parseEventDate(event.date_debut));
  
  return eventEndDate < today;
}
```

## Extraction des Informations de Prix

Les informations de prix peuvent être présentées de différentes façons:

```javascript
// Format simple
{
  prix_reduit: "22€00",
  ancien_prix: "2 031€00",
}

// Format avec catégories de prix
{
  catégories_prix: [
    {
      Catégorie: "Placement libre",
      Prix: ["22,00 €"]
    }
  ]
}

// Format billeterie
{
  prix_reduit: "13,59 €",
  purchase_url: "https://shotgun.live/fr/events/dylandylanresidencybadaboumparis"
}
```

Pour extraire les prix:

```javascript
function extractPriceInfo(event) {
  const priceInfo = {};
  
  // Prix réduit direct
  if (event.prix_reduit) {
    priceInfo.reducedPrice = event.prix_reduit;
  }
  
  // Ancien prix (avant réduction)
  if (event.ancien_prix && event.ancien_prix.trim() !== '') {
    priceInfo.originalPrice = event.ancien_prix;
  }
  
  // Catégories de prix
  if (event.catégories_prix && event.catégories_prix.length > 0) {
    priceInfo.priceCategories = event.catégories_prix.map(cat => ({
      category: cat.Catégorie,
      prices: cat.Prix
    }));
    
    // Extraire le prix le plus bas pour mise en avant
    const allPrices = event.catégories_prix
      .flatMap(cat => cat.Prix || [])
      .map(price => parseFloat(price.replace(/[^\d,]/g, '').replace(',', '.')))
      .filter(price => !isNaN(price));
    
    if (allPrices.length > 0) {
      priceInfo.lowestPrice = `${Math.min(...allPrices).toFixed(2).replace('.', ',')} €`;
    }
  }
  
  // URL d'achat
  if (event.purchase_url) {
    priceInfo.purchaseUrl = event.purchase_url;
  }
  
  return priceInfo;
}
```

## Utilisation des Lineups pour les Événements Musicaux

Les événements musicaux contiennent souvent un lineup d'artistes qu'il faut mettre en valeur:

```javascript
// Exemple d'événement avec lineup
{
  lineup: [
    {
      nom: "Otik",
      image: "https://res.cloudinary.com/shotgun/image/upload/c_limit,w_750/fl_lossy…"
    },
    {
      nom: "Goldie B",
      image: "https://res.cloudinary.com/shotgun/image/upload/c_limit,w_750/fl_lossy…"
    }
  ]
}
```

Pour utiliser le lineup dans la génération de posts:

```javascript
function generateLineupHighlight(event) {
  if (!event.lineup || event.lineup.length === 0) {
    return '';
  }
  
  // Extraire les noms des artistes
  const artistNames = event.lineup
    .map(artist => artist.nom)
    .filter(Boolean);
  
  if (artistNames.length === 0) {
    return '';
  }
  
  // Sélectionner un template selon le nombre d'artistes
  if (artistNames.length === 1) {
    return `Avec ${artistNames[0]} en tête d'affiche`;
  } else if (artistNames.length === 2) {
    return `Avec ${artistNames[0]} et ${artistNames[1]}`;
  } else {
    const mainActs = artistNames.slice(0, 2).join(', ');
    return `Avec ${mainActs} et d'autres artistes exceptionnels`;
  }
}
```

## Structure des Horaires

Les horaires peuvent être présentés différemment:

```javascript
// Format simple
horaires: [
  {
    jour: "ven",
    heure: "20:30"
  }
]

// Format avec plage horaire
horaires: [
  {
    jour: "sam",
    heure: "23:30 - 07:00"
  }
]
```

Pour formater les horaires:

```javascript
function formatSchedule(event) {
  if (!event.horaires || event.horaires.length === 0) {
    return '';
  }
  
  const dayMap = {
    'lun': 'lundi',
    'mar': 'mardi',
    'mer': 'mercredi',
    'jeu': 'jeudi',
    'ven': 'vendredi',
    'sam': 'samedi',
    'dim': 'dimanche'
  };
  
  const schedules = event.horaires.map(h => {
    const day = h.jour ? (dayMap[h.jour.toLowerCase()] || h.jour) : '';
    return `${day} ${h.heure || ''}`.trim();
  });
  
  return schedules.join(', ');
}
```

## Exemples de Génération de Posts avec DeepSeek

### Événement Culturel avec Date Spécifique

```javascript
// Prompt pour DeepSeek (événement culturel)
const prompt = `
Écris un post engageant pour un réseau social à propos de cet événement.

DÉTAILS DE L'ÉVÉNEMENT:
Nom: ${event.intitulé}
Lieu: ${event.lieu}
Date de début: ${formatEventDate(event.date_debut)}
Date de fin: ${formatEventDate(event.date_fin)}
Horaires: ${formatSchedule(event)}
Catégorie: ${event.catégorie}
Description: ${event.détail}
Prix: ${extractPriceInfo(event).reducedPrice || 'Non spécifié'}

INSTRUCTIONS:
- Le post doit être écrit en français
- Ton conversationnel et authentique
- Entre 30 et 60 mots
- Ne pas inventer d'informations qui ne sont pas dans les détails
- Mentionner la date et le prix si disponibles
- Créer un sentiment d'urgence approprié pour un événement limité dans le temps
`;
```

### Événement Musical avec Lineup

```javascript
// Prompt pour DeepSeek (événement musical)
const prompt = `
Écris un post engageant pour un réseau social à propos de cet événement musical.

DÉTAILS DE L'ÉVÉNEMENT:
Nom: ${event.intitulé}
Lieu: ${event.lieu}
Date: ${event.prochaines_dates || formatEventDate(event.date_debut)}
Horaires: ${formatSchedule(event)}
Catégorie: ${event.catégorie}
Lineup: ${event.lineup.map(a => a.nom).join(', ')}
Description: ${event.détail}
Prix: ${extractPriceInfo(event).reducedPrice || 'Non spécifié'}

INSTRUCTIONS:
- Le post doit être écrit en français
- Ton enthousiaste adapté à la musique électronique
- Entre 30 et 60 mots
- Mettre en avant le lineup et l'ambiance
- Ne pas inventer d'informations qui ne sont pas dans les détails
- Créer un sentiment de FOMO (peur de manquer quelque chose)
`;
```

## Conclusion

Pour générer des posts efficaces et factuellement corrects, il est essentiel de:

1. **Vérifier les dates** pour ne jamais poster sur des événements passés
2. **Respecter strictement les données existantes** sans inventer de contenu
3. **Adapter le format selon le type d'événement** (culturel, musical, etc.)
4. **Mettre en avant les éléments uniques** comme le lineup pour les événements musicaux
5. **Utiliser les informations de prix** quand elles sont disponibles pour créer de l'engagement

Cette approche garantit que les posts générés sont pertinents, factuellement corrects et maximisent l'engagement sans créer d'attentes irréalistes.