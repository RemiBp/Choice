# Guide de Prompt Engineering pour DeepSeek

Ce document présente les stratégies de prompt engineering optimisées pour la génération automatique de posts avec DeepSeek. Ces prompts sont spécialement conçus pour respecter strictement les données factuelles et générer du contenu engageant sans inventer d'informations.

## 🚨 Principes Fondamentaux

### Règle d'Or: Aucune Invention de Contenu

La règle la plus importante pour tous nos prompts est de **ne jamais inventer de faits, prix, récompenses, ou évaluations**. Tous les prompts doivent inclure cette consigne explicite et être conçus pour:

1. N'utiliser que les données fournies
2. Ne pas exagérer les caractéristiques
3. Ne pas inventer de témoignages clients
4. Ne pas créer d'offres ou de promotions fictives

### Structure Générale d'un Prompt Optimisé

```
Écris un post [type] pour [objectif]

DÉTAILS FACTUELS:
[informations exactes sur l'événement, le restaurant, etc.]

STYLE:
[description du ton et du style souhaités]

PUBLIC CIBLE:
[caractéristiques du public visé]

INSTRUCTIONS STRICTES:
- N'INVENTE AUCUNE INFORMATION non présente dans les détails fournis
- Utilise uniquement les faits présentés
- [autres instructions spécifiques]
...
```

## Types de Posts avec Exemples Concrets

### 1. Posts pour Événements Culturels (Format Loisir&Culture)

#### Template pour Événement Théâtral ou Culturel

```
Écris un post engageant pour un réseau social à propos de cet événement culturel.

DÉTAILS FACTUELS DE L'ÉVÉNEMENT:
Nom: [intitulé]
Lieu: [lieu]
Adresse: [adresse]
Date de début: [date_debut au format français]
Date de fin: [date_fin au format français]
Horaires: [formatés depuis horaires]
Catégorie: [catégorie]
Description: [détail]
Prix: [prix_reduit] (au lieu de [ancien_prix])
URL d'achat: [purchase_url]

STYLE DU POST: informationnel

PUBLIC CIBLE:
Intérêts: culture, théâtre, arts, sorties
Localisation: Paris
Démographie: 25-55 ans

INSTRUCTIONS STRICTES:
- Le post doit être écrit en français
- Ton conversationnel et cultivé
- Utiliser un langage précis et engageant
- Entre 40 et 70 mots
- Ne pas utiliser d'émojis ni de hashtags
- Mettre en valeur les dates et les prix TELS QUE FOURNIS
- N'INVENTE AUCUNE INFORMATION qui n'est pas présente dans les détails
- Ne pas inventer de critiques, de récompenses ou d'évaluations
- IMPORTANT: Réponds uniquement avec le texte du post
```

#### Exemple Concret pour "Le Misanthrope"

**Prompt:**
```
Écris un post engageant pour un réseau social à propos de cet événement culturel.

DÉTAILS FACTUELS DE L'ÉVÉNEMENT:
Nom: Le Misanthrope
Lieu: Théâtre du Marais
Adresse: 37 rue Volta, 75003 Paris
Date de début: 15/03/2025
Date de fin: 28/03/2025
Horaires: vendredi 20:00, samedi 20:00, dimanche 17:00
Catégorie: Théâtre » Comédie classique
Description: Une mise en scène moderne du chef d'œuvre de Molière. Alceste, homme intègre et épris de vérité, s'oppose aux mœurs hypocrites de son époque tout en étant amoureux de Célimène.
Prix: 25,50€ (au lieu de 35,00€)
URL d'achat: https://theatredumarais.fr/billeterie/le-misanthrope

STYLE DU POST: informationnel

PUBLIC CIBLE:
Intérêts: culture, théâtre, classique, Molière, sorties
Localisation: Paris
Démographie: 25-65 ans

INSTRUCTIONS STRICTES:
- Le post doit être écrit en français
- Ton conversationnel et cultivé
- Utiliser un langage précis et engageant
- Entre 40 et 70 mots
- Ne pas utiliser d'émojis ni de hashtags
- Mettre en valeur les dates et les prix TELS QUE FOURNIS
- N'INVENTE AUCUNE INFORMATION qui n'est pas présente dans les détails
- Ne pas inventer de critiques, de récompenses ou d'évaluations
- IMPORTANT: Réponds uniquement avec le texte du post
```

**Réponse DeepSeek (exemple):**
```
Le chef-d'œuvre de Molière revisité dans une mise en scène moderne ! "Le Misanthrope" s'installe au Théâtre du Marais du 15 au 28 mars 2025. Suivez l'intègre Alceste, épris de vérité et de la séduisante Célimène, dans sa croisade contre l'hypocrisie sociale. Représentations les vendredis et samedis à 20h, dimanches à 17h. Tarif réduit à 25,50€ au lieu de 35€. Une occasion rare de redécouvrir ce classique intemporel.
```

### 2. Posts pour Événements Musicaux avec Lineup

#### Template pour Concert/Soirée Musicale

```
Écris un post engageant pour un réseau social à propos de cet événement musical.

DÉTAILS FACTUELS DE L'ÉVÉNEMENT:
Nom: [intitulé]
Lieu: [lieu]
Adresse: [adresse]
Date: [prochaines_dates]
Horaires: [horaires.jour + horaires.heure]
Catégorie: [catégorie]
Lineup: [artist1], [artist2], [artist3]...
Description: [détail]
Prix: [prix_reduit]
URL d'achat: [purchase_url]

STYLE DU POST: enthousiaste

PUBLIC CIBLE:
Intérêts: musique, sorties, concerts, [genre musical spécifique]
Localisation: Paris
Démographie: 18-35 ans

INSTRUCTIONS STRICTES:
- Le post doit être écrit en français
- Ton excitant et énergique adapté à la musique
- Entre 40 et 70 mots
- Ne pas utiliser d'émojis ni de hashtags
- Mettre en valeur le lineup et l'ambiance
- Mentionner la date et le prix EXACTEMENT comme indiqués
- N'INVENTE AUCUNE INFORMATION qui n'est pas présente dans les détails
- IMPORTANT: Réponds uniquement avec le texte du post
```

#### Exemple Concret pour Soirée House

**Prompt:**
```
Écris un post engageant pour un réseau social à propos de cet événement musical.

DÉTAILS FACTUELS DE L'ÉVÉNEMENT:
Nom: Dylan Dylan Residency : Otik (+) Goldie B B2b Pura Pura
Lieu: BADABOUM
Adresse: 2 bis Rue des Taillandiers, 75011 Paris
Date: sam 15 févr.
Horaires: sam 23:30 - 07:00
Catégorie: house
Lineup: Otik, Goldie B, Pura Pura
Description: 📍 Samedi 15 février - 23h30/07h00 Club - Dylan Dylan residency : Otik et more!
Prix: 13,59 €
URL d'achat: https://shotgun.live/fr/events/dylandylanresidencybadaboumparis

STYLE DU POST: enthousiaste

PUBLIC CIBLE:
Intérêts: musique électronique, house, clubbing, sorties nocturnes
Localisation: Paris
Démographie: 18-35 ans

INSTRUCTIONS STRICTES:
- Le post doit être écrit en français
- Ton excitant et énergique adapté à la musique
- Entre 40 et 70 mots
- Ne pas utiliser d'émojis ni de hashtags
- Mettre en valeur le lineup et l'ambiance
- Mentionner la date et le prix EXACTEMENT comme indiqués
- N'INVENTE AUCUNE INFORMATION qui n'est pas présente dans les détails
- IMPORTANT: Réponds uniquement avec le texte du post
```

**Réponse DeepSeek (exemple):**
```
Le BADABOUM s'enflamme le samedi 15 février avec la Dylan Dylan Residency! Une nuit house d'exception de 23h30 jusqu'à 7h du matin avec un lineup qui fait vibrer: Otik aux platines, suivi du B2B explosif entre Goldie B et Pura Pura. Des sonorités house qui vous transporteront jusqu'au petit matin dans l'un des clubs les plus authentiques de Paris. Seulement 13,59€ l'entrée - réservez vite pour cette soirée qui s'annonce mémorable.
```

### 3. Posts pour Restaurants avec Menu Factuel

#### Template pour Restaurant

```
Écris un post engageant pour un réseau social à propos de ce restaurant.

DÉTAILS FACTUELS DU RESTAURANT:
Nom: [name]
Localisation: [address]
Catégorie: [category]
Description: [description]
Note moyenne: [rating]
Horaires: [hours]
Points forts du menu:
- [item1.name] ([item1.price]): [item1.description]
- [item2.name] ([item2.price]): [item2.description]
- [item3.name] ([item3.price]): [item3.description]

FOCUS DU POST: [focus_area]
STYLE DU POST: [style]

PUBLIC CIBLE:
Intérêts: gastronomie, cuisine, restaurants
Localisation: [adresse]

INSTRUCTIONS STRICTES:
- Le post doit être écrit en français
- Ton [style]
- Entre 40 et 70 mots
- Ne pas utiliser d'émojis ni de hashtags
- Donner envie aux lecteurs de visiter l'établissement
- Mettre en valeur UNIQUEMENT les plats MENTIONNÉS dans les détails
- N'INVENTE AUCUNE INFORMATION qui n'est pas présente dans les détails fournis
- Ne pas inventer de prix, récompenses, classements ou évaluations
- IMPORTANT: Réponds uniquement avec le texte du post
```

#### Exemple Concret pour Restaurant

**Prompt:**
```
Écris un post engageant pour un réseau social à propos de ce restaurant.

DÉTAILS FACTUELS DU RESTAURANT:
Nom: La Table de Marcel
Localisation: 14 rue Mabillon, 75006 Paris
Catégorie: Cuisine française, Bistro
Description: Bistro traditionnel proposant des plats de saison préparés avec des produits du marché. Atmosphère authentique dans un cadre chaleureux.
Note moyenne: 4.7
Horaires: Mardi-Samedi 12:00-14:30, 19:00-22:30
Points forts du menu:
- Tartare de bœuf au couteau (19,50€): Préparé minute avec des condiments frais et frites maison
- Magret de canard rôti (24,00€): Accompagné de légumes de saison et sauce au miel
- Tarte Tatin (9,50€): Servie tiède avec crème fraîche

FOCUS DU POST: menu_highlights
STYLE DU POST: professional

PUBLIC CIBLE:
Intérêts: gastronomie, cuisine française, cuisine de saison
Localisation: Paris, Saint-Germain-des-Prés

INSTRUCTIONS STRICTES:
- Le post doit être écrit en français
- Ton professionnel mais chaleureux
- Entre 40 et 70 mots
- Ne pas utiliser d'émojis ni de hashtags
- Donner envie aux lecteurs de visiter l'établissement
- Mettre en valeur UNIQUEMENT les plats MENTIONNÉS dans les détails
- N'INVENTE AUCUNE INFORMATION qui n'est pas présente dans les détails fournis
- Ne pas inventer de prix, récompenses, classements ou évaluations
- IMPORTANT: Réponds uniquement avec le texte du post
```

**Réponse DeepSeek (exemple):**
```
Au cœur de Saint-Germain-des-Prés, La Table de Marcel célèbre les saveurs authentiques de la cuisine française. Notre menu de saison propose des classiques revisités comme notre tartare de bœuf préparé minute au couteau, notre magret de canard rôti accompagné de légumes frais, ou notre tarte Tatin servie tiède. Dans notre cadre chaleureux, chaque plat raconte une histoire de terroir et de savoir-faire. Ouvert du mardi au samedi, midi et soir, pour vos moments gourmands.
```

### 4. Posts de Découverte Basés sur Intérêts Utilisateur

#### Template pour Post de Découverte

```
Écris un post personnalisé de découverte pour un utilisateur, basé sur ses intérêts et préférences.

INTÉRÊTS DE L'UTILISATEUR:
[intérêts principaux séparés par virgules]

DÉTAILS FACTUELS DE LA RECOMMANDATION:
Type: [type de recommandation: restaurant/event]
Nom: [nom]
Localisation: [localisation]
Catégorie: [catégorie]
Description: [description]
[autres détails pertinents]

STYLE DU POST: Personnalisé et basé sur les intérêts

INSTRUCTIONS STRICTES:
- Le post doit être écrit en français
- Ton chaleureux et personnalisé
- Expliquer pourquoi cette recommandation correspond aux intérêts de l'utilisateur
- Entre 40 et 70 mots
- Ne pas utiliser d'émojis ni de hashtags
- Ne pas utiliser directement "basé sur vos intérêts" 
- N'INVENTE AUCUNE INFORMATION qui n'est pas présente dans les détails fournis
- IMPORTANT: Réponds uniquement avec le texte du post
```

#### Exemple Concret pour Recommandation

**Prompt:**
```
Écris un post personnalisé de découverte pour un utilisateur, basé sur ses intérêts et préférences.

INTÉRÊTS DE L'UTILISATEUR:
jazz, musique live, cocktails, ambiance intimiste, sorties en soirée

DÉTAILS FACTUELS DE LA RECOMMANDATION:
Type: venue
Nom: Le Caveau de la Huchette
Localisation: 5 rue de la Huchette, 75005 Paris
Catégorie: Jazz club, Musique live
Description: Club de jazz historique dans une cave du 16e siècle, proposant concerts live tous les soirs et piste de danse. Atmosphère authentique et intimiste.
Prix entrée: 13€ (inclut une consommation)
Horaires: Tous les jours 21h00-02h30
Programme: Jam sessions le lundi, swing/bebop le week-end

STYLE DU POST: Personnalisé et basé sur les intérêts

INSTRUCTIONS STRICTES:
- Le post doit être écrit en français
- Ton chaleureux et personnalisé
- Expliquer pourquoi cette recommandation correspond aux intérêts de l'utilisateur
- Entre 40 et 70 mots
- Ne pas utiliser d'émojis ni de hashtags
- Ne pas utiliser directement "basé sur vos intérêts" 
- N'INVENTE AUCUNE INFORMATION qui n'est pas présente dans les détails fournis
- IMPORTANT: Réponds uniquement avec le texte du post
```

**Réponse DeepSeek (exemple):**
```
Amoureux de jazz et d'ambiances intimistes, Le Caveau de la Huchette vous attend! Nichée dans une cave du 16e siècle au Quartier Latin, cette institution propose chaque soir des concerts live dans un cadre authentique. Pour 13€ seulement (consommation incluse), imprégnez-vous de l'atmosphère unique qui a fait sa réputation. Les jam sessions du lundi et le swing du week-end vous transporteront dans l'âge d'or du jazz. Ouvert tous les soirs jusqu'à 2h30.
```

## Variations de Style et de Ton

### Styles pour Événements (avec exemples)

| Style | Description | Exemple d'utilisation |
|-------|-------------|------------------------|
| informationnel | Factuel, clair, informatif | Événements culturels, expositions |
| social_proof | Mise en avant de la popularité | Événements à succès, dernières places |
| fomo | Création d'un sentiment d'urgence | Événements limités dans le temps |
| question | Approche interrogative qui engage | Événements nichés, concepts originaux |
| enthusiastic | Ton très enthousiaste et énergique | Concerts, festivals, événements sportifs |

### Styles pour Restaurants (avec exemples)

| Style | Description | Exemple d'utilisation |
|-------|-------------|------------------------|
| professional | Ton soigné et élégant | Restaurants gastronomiques |
| casual | Décontracté et accessible | Bistros, cafés, restaurants familiaux |
| enthusiastic | Énergique et passionné | Nouveaux concepts, cuisines innovantes |
| elegant | Sophistiqué et raffiné | Restaurants haut de gamme |
| humorous | Léger et amusant | Concepts originaux, ambiances décontractées |

## Instructions Claires pour Eviter les Problèmes Courants

### Restrictions Explicites 

Toujours inclure ces instructions dans les prompts:

```
INSTRUCTIONS STRICTES:
- N'INVENTE AUCUNE INFORMATION qui n'est pas présente dans les détails fournis
- Ne pas inventer de prix, récompenses, classements ou évaluations
- Utiliser uniquement les faits présentés dans les détails
- Ne pas mentionner de personnes/célébrités non liées à l'événement
- Ne pas créer de fausses promotions ou offres
```

### Exemples de Problèmes à Éviter

| Problème | Exemple à éviter | Correction |
|----------|------------------|------------|
| Prix inventés | "Menu à partir de 15€" quand aucun prix n'est fourni | "Découvrez notre menu saisonnier" (sans mention de prix) |
| Récompenses fictives | "Élu meilleur restaurant italien 2024" | "Notre restaurant italien au cœur de Paris" |
| Témoignages fabriqués | "Nos clients adorent..." | "Une expérience italienne authentique" |
| Offres inventées | "Promotion spéciale ce weekend" | "Ouvert ce weekend pour vous accueillir" |

## Parametrage du Modèle DeepSeek

### Configuration Optimale

Pour obtenir des résultats cohérents tout en permettant une certaine créativité:

```javascript
const params = {
  temperature: 0.7,    // Équilibre entre créativité et précision
  top_p: 0.92,         // Bonne diversité sans trop s'éloigner du sujet
  max_tokens: 200,     // Suffisant pour un post complet
  stop_sequences: ["\n\n"] // Évite les explications supplémentaires
};
```

### Ajustements par Type de Contenu

| Type de contenu | Temperature | Justification |
|-----------------|-------------|---------------|
| Posts informationnels | 0.6 | Plus factuel, moins créatif |
| Posts événement culturel | 0.7 | Équilibre créativité/précision |
| Posts événement musical | 0.75 | Plus d'énergie, style plus libre |
| Posts restaurant | 0.7 | Descriptif mais engageant |
| Posts découverte | 0.8 | Plus personnalisé et créatif |

## Utilisation de l'API DeepSeek

### Exemple d'Intégration avec Vast.ai

```javascript
async function generatePostWithDeepSeek(prompt) {
  try {
    const response = await axios.post('https://79.116.152.57:39370/terminals/1/generate', {
      prompt,
      max_tokens: 200,
      temperature: 0.7,
      top_p: 0.92,
      api_key: process.env.DEEPSEEK_API_KEY
    }, {
      headers: {
        'Content-Type': 'application/json'
      },
      timeout: 30000 // 30 second timeout
    });
    
    if (response.data && response.data.text) {
      return response.data.text.trim();
    } else {
      throw new Error('Invalid response format');
    }
  } catch (error) {
    console.error('Error generating content:', error);
    return null;
  }
}
```

### Gestion des Erreurs et Fallbacks

Toujours implémenter un système de contenu de secours:

```javascript
// Contenu de secours par catégorie
const fallbackContent = {
  event: "Ne manquez pas cet événement exceptionnel ! Une occasion unique de découvrir des talents locaux dans un cadre intimiste.",
  restaurant: "Une cuisine authentique qui met en valeur des produits de saison sélectionnés avec soin. Une adresse à découvrir absolument !",
  discovery: "Voici une recommandation qui correspond parfaitement à vos intérêts. Une expérience qui promet de vous surprendre agréablement."
};

// Utilisation du fallback approprié en cas d'erreur
function getFallbackContent(type, prompt) {
  if (prompt.includes('ÉVÉNEMENT')) {
    return fallbackContent.event;
  } else if (prompt.includes('RESTAURANT')) {
    return fallbackContent.restaurant;
  } else {
    return fallbackContent.discovery;
  }
}
```

## Conclusion

Ces directives de prompt engineering sont spécifiquement conçues pour respecter la contrainte fondamentale de ne jamais inventer de contenu. Elles permettent de:

1. **Générer des posts engageants basés uniquement sur des données factuelles**
2. **Adapter le ton et le style au type de contenu tout en restant authentique**
3. **Mettre en valeur les aspects uniques d'un événement ou restaurant sans exagération**
4. **Éviter les affirmations trompeuses ou les informations inventées**
5. **Respecter les structures variées de la base MongoDB**

En suivant ces directives, les posts générés seront à la fois authentiques, engageants et dignes de confiance, créant ainsi une expérience utilisateur de qualité tout en respectant l'intégrité des données.