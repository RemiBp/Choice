/**
 * Auto Post Generator using DeepSeek
 * 
 * This service connects to a DeepSeek LLM running on a vast.ai server
 * to generate engaging, personalized posts for the feed.
 */

const axios = require('axios');
require('dotenv').config();

// Configuration - Using the terminal URL provided by the user
const DEEPSEEK_SERVER_URL = process.env.DEEPSEEK_SERVER_URL || 'https://79.116.152.57:39370/terminals/1/generate';
const DEEPSEEK_API_KEY = process.env.DEEPSEEK_API_KEY;

/**
 * Service for generating automatic posts using DeepSeek
 */
class AutoPostGenerator {
  /**
   * Constructor for AutoPostGenerator
   * @param {Object} dependencies - Dependency injection for services
   */
  constructor(dependencies = {}) {
    this.postService = dependencies.postService;
    this.userService = dependencies.userService;
    this.producerService = dependencies.producerService;
    this.eventService = dependencies.eventService;
    this.deepSeekClient = dependencies.deepSeekClient || new DeepSeekClient();
  }

  /**
   * Generate posts for upcoming events
   * @param {Object} options - Options for generation
   * @returns {Promise<Array>} - Generated posts
   */
  async generateEventPosts(options = {}) {
    try {
      console.log('🚀 Generating automatic posts for events');
      
      // Get upcoming events that warrant posts
      const events = await this.eventService.getUpcomingEvents({
        daysAhead: options.daysAhead || 14,
        minRating: options.minRating || 4.0,
        limit: options.limit || 10
      });
      
      console.log(`📅 Found ${events.length} upcoming events for potential posts`);
      
      const generatedPosts = [];
      
      for (const event of events) {
        // Skip if we already have a recent automatic post for this event
        const hasRecentPost = await this.postService.hasRecentAutomaticPost({
          targetId: event._id,
          targetType: 'event',
          daysBack: 7
        });
        
        if (hasRecentPost) {
          console.log(`⏭️ Skipping event ${event.intitulé || event.nom}: recent post exists`);
          continue;
        }
        
        // Check if the event has already ended
        const today = new Date();
        const eventEndDate = event.date_fin ? new Date(this.parseEventDate(event.date_fin)) : 
                            (event.horaires && event.horaires.length > 0 && event.horaires[0].jour ? 
                            this.parseEventDateFromHoraires(event.horaires[0], event.prochaines_dates) :
                            new Date(this.parseEventDate(event.date_debut)));
        
        if (eventEndDate < today) {
          console.log(`⏭️ Skipping event ${event.intitulé || event.nom}: already ended (${eventEndDate.toLocaleDateString()})`);
          continue;
        }
        
        // Determine the post style based on event attributes and random variation
        const postStyle = this.selectEventPostStyle(event);
        
        // Find target audience based on location and interests
        const targetAudience = await this.determineEventTargetAudience(event);
        
        // Extract factual event details
        const eventDetails = this.extractEventDetails(event);
        
        // Generate post content using DeepSeek with ONLY factual information
        const postContent = await this.deepSeekClient.generateEventPost({
          event: eventDetails,
          style: postStyle,
          audience: targetAudience
        });
        
        if (!postContent) {
          console.log(`❌ Failed to generate content for event ${event.intitulé || event.nom}`);
          continue;
        }
        
        // Create the post in the database
        const newPost = await this.postService.createPost({
          content: postContent,
          target_id: event._id,
          target_type: 'event',
          target_name: event.intitulé || event.nom,
          posted_at: new Date(),
          automation_type: 'event_promotion',
          auto_generated: true,
          media: event.photos || [],
          location: {
            name: event.lieu,
            coordinates: event.coordinates
          }
        });
        
        console.log(`✅ Created automatic post for event: ${event.intitulé || event.nom}`);
        generatedPosts.push(newPost);
      }
      
      return {
        generated: generatedPosts.length,
        posts: generatedPosts
      };
    } catch (error) {
      console.error('❌ Error generating event posts:', error);
      throw error;
    }
  }
  
  /**
   * Parse event date string to Date object
   * @param {String} dateStr - Date string (could be in different formats)
   * @returns {Date} - Parsed date object
   */
  parseEventDate(dateStr) {
    // Handle different date formats
    if (!dateStr) return new Date(); // Default to today if no date
    
    // Format: DD/MM/YYYY
    if (dateStr.includes('/')) {
      const [day, month, year] = dateStr.split('/').map(part => parseInt(part, 10));
      return new Date(year, month - 1, day);
    }
    
    // Try standard Date parsing for ISO formats
    return new Date(dateStr);
  }
  
  /**
   * Parse event date from horaires and prochaines_dates
   * @param {Object} horaire - Horaires object
   * @param {String} prochaines_dates - String with upcoming dates
   * @returns {Date} - Parsed date object
   */
  parseEventDateFromHoraires(horaire, prochaines_dates) {
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
  
  /**
   * Extract detailed event information using only factual data
   * @param {Object} event - Event object
   * @returns {Object} - Processed event details
   */
  extractEventDetails(event) {
    // Base details
    const details = {
      name: event.intitulé || event.nom || '',
      venue: event.lieu || '',
      location: event.location?.adresse || '',
      coordinates: event.location?.coordinates || [],
      category: event.catégorie || event.category || '',
      description: event.détail || event.description || '',
    };
    
    // Date information
    if (event.date_debut) {
      details.start_date = this.formatEventDate(event.date_debut);
    }
    
    if (event.date_fin) {
      details.end_date = this.formatEventDate(event.date_fin);
    }
    
    // Horaires (time schedules)
    if (event.horaires && event.horaires.length > 0) {
      details.schedules = event.horaires.map(h => ({
        day: h.jour || '',
        time: h.heure || ''
      }));
    }
    
    // Price information
    if (event.prix_reduit) {
      details.reduced_price = event.prix_reduit;
    }
    
    if (event.ancien_prix) {
      details.original_price = event.ancien_prix;
    }
    
    // Lineup for music events
    if (event.lineup && event.lineup.length > 0) {
      details.lineup = event.lineup.map(artist => ({
        name: artist.nom || '',
        image: artist.image || ''
      }));
    }
    
    // Ticket purchase URL
    if (event.purchase_url) {
      details.purchase_url = event.purchase_url;
    }
    
    return details;
  }
  
  /**
   * Format event date for display
   * @param {String} dateStr - Date string
   * @returns {String} - Formatted date
   */
  formatEventDate(dateStr) {
    try {
      const date = this.parseEventDate(dateStr);
      return date.toLocaleDateString('fr-FR', {
        weekday: 'long',
        day: 'numeric',
        month: 'long',
        year: 'numeric'
      });
    } catch (e) {
      return dateStr; // Return original if parsing fails
    }
  }

  /**
   * Generate posts for restaurants/producers
   * @param {Object} options - Options for generation
   * @returns {Promise<Array>} - Generated posts
   */
  async generateProducerPosts(options = {}) {
    try {
      console.log('🚀 Generating automatic posts for producers');
      
      // Get producers with auto-post enabled
      const producers = await this.producerService.getProducersWithAutoPostEnabled({
        limit: options.limit || 10
      });
      
      console.log(`🍽️ Found ${producers.length} producers with auto-post enabled`);
      
      const generatedPosts = [];
      
      for (const producer of producers) {
        // Skip if we already have a recent automatic post for this producer
        const hasRecentPost = await this.postService.hasRecentAutomaticPost({
          targetId: producer._id,
          targetType: 'producer',
          daysBack: producer.auto_post_settings?.frequency === 'weekly' ? 7 : 3
        });
        
        if (hasRecentPost) {
          console.log(`⏭️ Skipping producer ${producer.name}: recent post exists`);
          continue;
        }
        
        // Get producer-specific data for post generation
        const producerDetails = await this.producerService.getProducerDetails(producer._id);
        
        // Determine the post style based on producer settings and random variation
        const postStyle = producer.auto_post_settings?.tone || 'professional';
        
        // Determine focus area based on settings or auto-select
        const focusArea = this.selectProducerFocusArea(producer);
        
        // Find target audience based on location and interests
        const targetAudience = await this.determineProducerTargetAudience(producer);
        
        // Extract factual producer information - NO INVENTIONS
        const producerInfo = this.extractProducerDetails(producer, producerDetails);
        
        // Generate post content using DeepSeek with ONLY factual information
        const postContent = await this.deepSeekClient.generateProducerPost({
          producer: producerInfo,
          style: postStyle,
          focusArea: focusArea,
          audience: targetAudience
        });
        
        if (!postContent) {
          console.log(`❌ Failed to generate content for producer ${producer.name}`);
          continue;
        }
        
        // Create the post in the database
        const newPost = await this.postService.createPost({
          content: postContent,
          producer_id: producer._id,
          target_id: producer._id,
          target_type: 'producer',
          target_name: producer.name,
          posted_at: new Date(),
          automation_type: 'producer_auto',
          auto_generated: true,
          media: this.selectProducerMedia(producer, focusArea),
          location: {
            name: producer.address,
            coordinates: producer.coordinates
          }
        });
        
        console.log(`✅ Created automatic post for producer: ${producer.name}`);
        generatedPosts.push(newPost);
      }
      
      return {
        generated: generatedPosts.length,
        posts: generatedPosts
      };
    } catch (error) {
      console.error('❌ Error generating producer posts:', error);
      throw error;
    }
  }
  
  /**
   * Generate user interest-based discovery posts
   * @param {Object} options - Options for generation
   * @returns {Promise<Array>} - Generated posts
   */
  async generateDiscoveryPosts(options = {}) {
    try {
      console.log('🚀 Generating discovery posts based on user interests');
      
      // Get active users who might benefit from discovery posts
      const users = await this.userService.getActiveUsers({
        minInteractions: options.minInteractions || 5,
        maxLastActivity: options.maxLastActivity || 7, // days
        limit: options.limit || 20
      });
      
      console.log(`👥 Found ${users.length} active users for potential discovery posts`);
      
      const generatedPosts = [];
      
      for (const user of users) {
        // Build interest profile from user data
        const interestProfile = await this.userService.buildUserInterestProfile(user._id);
        
        // Skip users with insufficient interest data
        if (!interestProfile || Object.keys(interestProfile.interests).length < 2) {
          console.log(`⏭️ Skipping user ${user._id}: insufficient interest data`);
          continue;
        }
        
        // Find matching content (events or producers) based on interests
        const recommendations = await this.findMatchingContent(interestProfile);
        
        if (!recommendations || recommendations.length === 0) {
          console.log(`⏭️ Skipping user ${user._id}: no matching content found`);
          continue;
        }
        
        // Select top recommendation that hasn't been shown to user
        const topRecommendation = recommendations[0];
        
        // Generate post content using DeepSeek
        const postContent = await this.deepSeekClient.generateDiscoveryPost({
          user: {
            interests: interestProfile.interests,
            locationPreferences: interestProfile.locations
          },
          recommendation: {
            type: topRecommendation.type,
            name: topRecommendation.name,
            location: topRecommendation.location,
            category: topRecommendation.category,
            description: topRecommendation.description
          }
        });
        
        if (!postContent) {
          console.log(`❌ Failed to generate discovery content for user ${user._id}`);
          continue;
        }
        
        // Create the post in the database
        const newPost = await this.postService.createPost({
          content: postContent,
          target_id: topRecommendation._id,
          target_type: topRecommendation.type,
          target_name: topRecommendation.name,
          posted_at: new Date(),
          automation_type: 'discovery',
          auto_generated: true,
          media: topRecommendation.photos || [],
          location: {
            name: topRecommendation.location,
            coordinates: topRecommendation.coordinates
          },
          // Associate with user to avoid showing same recommendation again
          for_user_id: user._id 
        });
        
        console.log(`✅ Created discovery post for user: ${user._id}`);
        generatedPosts.push(newPost);
      }
      
      return {
        generated: generatedPosts.length,
        posts: generatedPosts
      };
    } catch (error) {
      console.error('❌ Error generating discovery posts:', error);
      throw error;
    }
  }
  
  /**
   * Select an appropriate post style for an event
   * @param {Object} event - The event object
   * @returns {String} - Selected post style
   */
  selectEventPostStyle(event) {
    const styles = ['social_proof', 'fomo', 'informational', 'question', 'enthusiastic'];
    
    // If the event is very soon, prefer FOMO style
    const eventDate = new Date(event.date_debut);
    const daysTillEvent = Math.ceil((eventDate - new Date()) / (1000 * 60 * 60 * 24));
    
    if (daysTillEvent <= 3) {
      return 'fomo';
    }
    
    // For cultural events, prefer informational style more often
    if (event.category && 
        (typeof event.category === 'string' && event.category.toLowerCase().includes('culture')) ||
        (Array.isArray(event.category) && event.category.some(c => c.toLowerCase().includes('culture')))) {
      // 50% chance of informational
      if (Math.random() < 0.5) {
        return 'informational';
      }
    }
    
    // Otherwise random selection for variety
    return styles[Math.floor(Math.random() * styles.length)];
  }
  
  /**
   * Determine target audience for an event post
   * @param {Object} event - The event object
   * @returns {Promise<Object>} - Target audience data
   */
  async determineEventTargetAudience(event) {
    // Extract event location
    const eventLocation = event.coordinates || event.lieu;
    
    // Find users who might be interested in this event type
    const interestedUsers = await this.userService.findUsersInterestedInCategory(
      event.category, 
      { limit: 20 }
    );
    
    // Extract common interests and demographics
    const interests = {};
    const demographics = { age: {}, gender: {} };
    
    interestedUsers.forEach(user => {
      // Aggregate interests
      (user.liked_tags || []).forEach(tag => {
        interests[tag] = (interests[tag] || 0) + 1;
      });
      
      // Aggregate demographics if available
      if (user.age) {
        const ageGroup = Math.floor(user.age / 10) * 10;
        demographics.age[ageGroup] = (demographics.age[ageGroup] || 0) + 1;
      }
      
      if (user.gender) {
        demographics.gender[user.gender] = (demographics.gender[user.gender] || 0) + 1;
      }
    });
    
    // Get top interests
    const topInterests = Object.entries(interests)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 5)
      .map(entry => entry[0]);
    
    // Get dominant age group if any
    let dominantAgeGroup = null;
    if (Object.keys(demographics.age).length > 0) {
      dominantAgeGroup = Object.entries(demographics.age)
        .sort((a, b) => b[1] - a[1])[0][0];
    }
    
    // Get dominant gender if any
    let dominantGender = null;
    if (Object.keys(demographics.gender).length > 0) {
      dominantGender = Object.entries(demographics.gender)
        .sort((a, b) => b[1] - a[1])[0][0];
    }
    
    return {
      interests: topInterests,
      location: eventLocation,
      demographics: {
        ageGroup: dominantAgeGroup,
        gender: dominantGender
      }
    };
  }
  /**
   * Extract detailed producer information using only factual data
   * @param {Object} producer - Producer object
   * @param {Object} producerDetails - Additional producer details
   * @returns {Object} - Processed producer details
   */
  extractProducerDetails(producer, producerDetails) {
    // Base details
    const details = {
      name: producer.name || '',
      location: producer.address || '',
      coordinates: producer.coordinates || [],
      category: Array.isArray(producer.category) ? producer.category.join(', ') : producer.category || '',
      description: producer.description || '',
      rating: producer.rating || null,
    };
    
    // Menu items - ONLY use actual menu items from the database
    if (producer['Items Indépendants'] && Array.isArray(producer['Items Indépendants'])) {
      details.menu_categories = producer['Items Indépendants'].map(category => ({
        name: category.catégorie || '',
        items: (category.items || []).map(item => ({
          name: item.nom || '',
          description: item.description || '',
          price: item.prix || '',
          rating: item.note || null
        }))
      }));
      
      // Extract top rated menu items if available
      const allItems = producer['Items Indépendants']
        .flatMap(category => 
          (category.items || []).map(item => ({
            ...item,
            category: category.catégorie
          }))
        );
      
      // Sort by rating if available
      const topItems = allItems
        .filter(item => item.note)
        .sort((a, b) => (b.note || 0) - (a.note || 0))
        .slice(0, 3);
      
      if (topItems.length > 0) {
        details.top_items = topItems.map(item => ({
          name: item.nom || '',
          description: item.description || '',
          price: item.prix || '',
          rating: item.note || null,
          category: item.category || ''
        }));
      }
    }
    
    // Upcoming events if available
    if (producer.upcoming_events && producer.upcoming_events.length > 0) {
      details.upcoming_events = producer.upcoming_events.map(event => ({
        name: event.intitulé || event.nom || '',
        date: event.date_debut || '',
        description: event.détail || event.description || ''
      }));
    }
    
    // Additional details provided by producerDetails
    if (producerDetails) {
      if (producerDetails.hours) {
        details.hours = producerDetails.hours;
      }
      
      if (producerDetails.specialties && producerDetails.specialties.length > 0) {
        details.specialties = producerDetails.specialties;
      }
    }
    
    return details;
  }
  
  /**
   * Select a focus area for producer post generation
   * @param {Object} producer - The producer object
   * @returns {String} - Selected focus area
   */
  selectProducerFocusArea(producer) {
    // If producer has explicit focus areas, use those
    if (producer.auto_post_settings?.focus_areas && 
        Array.isArray(producer.auto_post_settings.focus_areas) &&
        producer.auto_post_settings.focus_areas.length > 0) {
          
      // Randomly select from specified focus areas
      const focusAreas = producer.auto_post_settings.focus_areas;
      return focusAreas[Math.floor(Math.random() * focusAreas.length)];
    }
    
    // Otherwise, select based on producer data and priorities
    
    // Is there a special menu/dish to highlight?
    if (producer['Items Indépendants'] && 
        Array.isArray(producer['Items Indépendants']) &&
        producer['Items Indépendants'].length > 0) {
      // Find items with high ratings if available
      const specialItems = producer['Items Indépendants']
        .flatMap(section => section.items || [])
        .filter(item => item.note && item.note >= 8.0);
        
      if (specialItems.length > 0) {
        return 'specialty_dish';
      }
    }
    
    // Check if there are upcoming events at the venue
    if (producer.upcoming_events && producer.upcoming_events.length > 0) {
      // Only select upcoming events that haven't ended
      const today = new Date();
      const upcomingEvents = producer.upcoming_events.filter(event => {
        const eventEndDate = event.date_fin ? 
          new Date(this.parseEventDate(event.date_fin)) : 
          new Date(this.parseEventDate(event.date_debut));
        return eventEndDate >= today;
      });
      
      if (upcomingEvents.length > 0) {
        return 'upcoming_event';
      }
    }
    
    // Default focuses with weighted probability
    const defaultFocuses = [
      { area: 'ambiance', weight: 25 },
      { area: 'menu_highlights', weight: 35 },
      { area: 'location', weight: 15 },
      { area: 'unique_selling_point', weight: 25 }
    ];
    
    // Simple weighted random selection
    const totalWeight = defaultFocuses.reduce((sum, focus) => sum + focus.weight, 0);
    let random = Math.random() * totalWeight;
    
    for (const focus of defaultFocuses) {
      random -= focus.weight;
      if (random <= 0) {
        return focus.area;
      }
    }
    
    return 'menu_highlights'; // Fallback
  }
  
  /**
   * Select appropriate media for a producer post
   * @param {Object} producer - The producer object
   * @param {String} focusArea - The post focus area
   * @returns {Array} - Selected media URLs
   */
  selectProducerMedia(producer, focusArea) {
    // Default to producer photos if available
    if (!producer.photos || !Array.isArray(producer.photos) || producer.photos.length === 0) {
      return [];
    }
    
    // For specialty dish focus, try to find dish photos
    if (focusArea === 'specialty_dish' && producer.dish_photos && producer.dish_photos.length > 0) {
      return [producer.dish_photos[0]];
    }
    
    // For ambiance focus, try to find interior photos
    if (focusArea === 'ambiance' && producer.interior_photos && producer.interior_photos.length > 0) {
      return [producer.interior_photos[0]];
    }
    
    // Otherwise return first producer photo
    return [producer.photos[0]];
  }
  
  /**
   * Find content that matches user interest profile
   * @param {Object} interestProfile - User's interest profile
   * @returns {Promise<Array>} - Matching content items
   */
  async findMatchingContent(interestProfile) {
    // This would involve querying both producers and events that match the user's interests
    // For simplicity, we'll just return a mock implementation
    
    // In a real implementation, we would:
    // 1. Extract top categories and locations from the interest profile
    // 2. Find events and producers that match these interests
    // 3. Score them by relevance to the user's preferences
    // 4. Return the top matches
    
    const mockRecommendations = [
      {
        _id: '123456abcdef',
        type: 'producer',
        name: 'Le Bistrot Parisien',
        location: 'Montmartre, Paris',
        category: ['French Cuisine', 'Wine Bar'],
        description: 'Authentic French bistro with a modern twist.',
        coordinates: [48.8566, 2.3522]
      },
      {
        _id: '789012ghijkl',
        type: 'event',
        name: 'Jazz Night at Le Caveau',
        location: 'Saint-Germain-des-Prés, Paris',
        category: ['Music', 'Jazz', 'Live Performance'],
        description: 'An evening of smooth jazz with renowned local musicians.',
        coordinates: [48.8539, 2.3386]
      }
    ];
    
    // In a real implementation, we'd return the actual recommendations
    return mockRecommendations;
  }
  
  /**
   * Determine target audience for a producer post
   * @param {Object} producer - The producer object
   * @returns {Promise<Object>} - Target audience data
   */
  async determineProducerTargetAudience(producer) {
    // Similar implementation to determineEventTargetAudience
    // This would analyze the producer's customer base and area
    
    return {
      interests: ['cuisine', 'dining', 'restaurants'],
      location: producer.address,
      demographics: {
        ageGroup: '30',
        gender: null
      }
    };
  }
}

/**
 * Client for interacting with DeepSeek API server
 */
class DeepSeekClient {
  constructor() {
    this.serverUrl = DEEPSEEK_SERVER_URL;
    this.apiKey = DEEPSEEK_API_KEY;
  }
  
  /**
   * Generate a post for an event
   * @param {Object} params - Event data and generation parameters
   * @returns {Promise<String>} - Generated post content
   */
  async generateEventPost(params) {
    const { event, style, audience } = params;
    
    // Build prompt for event post
    const prompt = this.buildEventPrompt(event, style, audience);
    
    // Call DeepSeek API
    return this.callDeepSeekAPI(prompt);
  }
  
  /**
   * Generate a post for a producer
   * @param {Object} params - Producer data and generation parameters
   * @returns {Promise<String>} - Generated post content
   */
  async generateProducerPost(params) {
    const { producer, style, focusArea, audience } = params;
    
    // Build prompt for producer post
    const prompt = this.buildProducerPrompt(producer, style, focusArea, audience);
    
    // Call DeepSeek API
    return this.callDeepSeekAPI(prompt);
  }
  
  /**
   * Generate a discovery post based on user interests
   * @param {Object} params - User interest data and recommendation
   * @returns {Promise<String>} - Generated post content
   */
  async generateDiscoveryPost(params) {
    const { user, recommendation } = params;
    
    // Build prompt for discovery post
    const prompt = this.buildDiscoveryPrompt(user, recommendation);
    
    // Call DeepSeek API
    return this.callDeepSeekAPI(prompt);
  }
  
  /**
   * Build prompt for event post generation
   * @param {Object} event - Event data
   * @param {String} style - Post style
   * @param {Object} audience - Target audience data
   * @returns {String} - Generated prompt
   */
  buildEventPrompt(event, style, audience) {
    // Construct a prompt based on the event details and desired style
    
    // Examples for different styles
    const styleExamples = {
      social_proof: "J'ai découvert un spectacle incroyable au Théâtre de la Ville hier soir. Une mise en scène qui vous transporte complètement, des acteurs brillants, une expérience que je recommande vivement !",
      
      fomo: "Dernières places disponibles pour le concert événement de l'année ! Tous ceux qui y étaient l'an dernier en parlent encore. Vous ne voulez pas être celui qui va manquer ça !",
      
      informational: "L'exposition \"Lumières de Paris\" ouvre ses portes ce weekend au Grand Palais. Une collection unique de 200 œuvres retraçant l'évolution de la représentation de la lumière dans l'art parisien du 19ème siècle.",
      
      question: "Amateur de jazz manouche ? Que diriez-vous de découvrir la nouvelle génération de talents dans un cadre intimiste au Sunset-Sunside ce vendredi ?",
      
      enthusiastic: "Je suis complètement sous le charme de ce nouveau spectacle au Théâtre du Châtelet ! Une énergie folle, des costumes éblouissants et une histoire qui vous prend aux tripes. À voir absolument !"
    };
    
    // Audience interests as comma-separated list
    const interestList = audience?.interests?.join(', ') || 'arts, culture, divertissement';
    
    // Demographics text if available
    let demographicsText = '';
    if (audience?.demographics?.ageGroup || audience?.demographics?.gender) {
      demographicsText = 'Principalement pour ';
      if (audience?.demographics?.gender) {
        demographicsText += audience.demographics.gender === 'male' ? 'hommes' : 
                           audience.demographics.gender === 'female' ? 'femmes' : 'tout public';
      }
      if (audience?.demographics?.ageGroup) {
        demographicsText += audience?.demographics?.gender ? ' ' : '';
        demographicsText += `${audience.demographics.ageGroup}-${parseInt(audience.demographics.ageGroup) + 9} ans`;
      }
    }
    
    // Get example for the selected style
    const styleExample = styleExamples[style] || styleExamples.informational;
    
    // Build schedule text
    let scheduleText = '';
    if (event.schedules && event.schedules.length > 0) {
      const scheduleItems = event.schedules.map(s => `${s.day}: ${s.time}`);
      scheduleText = `Horaires: ${scheduleItems.join(', ')}`;
    }
    
    // Build lineup text if available
    let lineupText = '';
    if (event.lineup && event.lineup.length > 0) {
      const artists = event.lineup.map(a => a.name).filter(Boolean);
      if (artists.length > 0) {
        lineupText = `Lineup: ${artists.join(', ')}`;
      }
    }
    
    // Build price text
    let priceText = '';
    if (event.reduced_price && event.original_price) {
      priceText = `Prix: ${event.reduced_price} (au lieu de ${event.original_price})`;
    } else if (event.reduced_price) {
      priceText = `Prix: ${event.reduced_price}`;
    }
    
    // Construct the final prompt with all FACTUAL details
    return `
    Écris un post engageant pour un réseau social à propos de cet événement.
    
    DÉTAILS DE L'ÉVÉNEMENT:
    Nom: ${event.name}
    Lieu: ${event.venue}
    ${event.location ? `Adresse: ${event.location}\n` : ''}
    ${event.start_date ? `Date de début: ${event.start_date}\n` : ''}
    ${event.end_date ? `Date de fin: ${event.end_date}\n` : ''}
    ${scheduleText ? `${scheduleText}\n` : ''}
    Catégorie: ${event.category}
    Description: ${event.description}
    ${priceText ? `${priceText}\n` : ''}
    ${lineupText ? `${lineupText}\n` : ''}
    ${event.purchase_url ? `Lien d'achat: ${event.purchase_url}\n` : ''}
    
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
    - Utiliser un langage varié et engageant
    - Entre 30 et 60 mots
    - Ne pas utiliser d'émojis ni de hashtags
    - Créer un sentiment de FOMO (peur de manquer quelque chose)
    - Ne jamais inclure de texte générique comme [nom] ou [événement]
    - Ne pas commencer par des phrases comme "Attention!" ou "Ne manquez pas!"
    - IMPORTANT: N'INVENTE AUCUNE INFORMATION qui n'est pas présente dans les détails de l'événement
    - N'invente pas de prix, de récompenses, ou d'évaluations
    - Utilise uniquement les faits présentés dans les détails de l'événement
    
    IMPORTANT: Réponds uniquement avec le texte du post, sans explications ni formatage supplémentaire.
    `;
  }
  
  /**
   * Build prompt for producer post generation
   * @param {Object} producer - Producer data
   * @param {String} style - Post style/tone
   * @param {String} focusArea - Area to focus on
   * @param {Object} audience - Target audience data
   * @returns {String} - Generated prompt
   */
  buildProducerPrompt(producer, style, focusArea, audience) {
    // Examples for different styles
    const styleExamples = {
      professional: "Notre nouvelle carte d'automne est arrivée, avec des produits de saison sélectionnés chez les meilleurs producteurs. Venez découvrir des saveurs authentiques dans un cadre chaleureux.",
      
      casual: "On a concocté de nouvelles recettes qui vont vous faire craquer ! Notre chef a mis tout son cœur dans cette carte d'automne. Passez nous voir, on vous attend !",
      
      enthusiastic: "Les premiers champignons d'automne sont arrivés en cuisine et notre chef est comme un enfant devant un sapin de Noël ! Venez goûter notre risotto aux cèpes fraîchement cueillis, c'est une pure merveille !",
      
      elegant: "L'automne nous inspire une symphonie de saveurs où se marient délicatement champignons des bois et gibier. Notre nouvelle carte célèbre ce moment privilégié de l'année gastronomique.",
      
      humorous: "C'est la saison des pulls et des bons petits plats qui réchauffent ! Notre chef a troqué son chapeau contre un bonnet et ça lui donne des idées folles. Venez goûter avant qu'on le ramène à la raison !"
    };
    
    // Focus area examples WITHOUT INVENTED CONTENT - emphasizing the real content
    const focusAreaExamples = {
      menu_highlights: "Notre carte met en valeur les produits de saison, avec une attention particulière aux saveurs authentiques et aux préparations maison. Chaque plat est une invitation à découvrir notre vision de la gastronomie.",
      
      specialty_dish: "Notre chef vous propose des créations uniques qui reflètent notre savoir-faire et notre passion pour la cuisine. Des plats signatures qui font notre réputation et que nous prenons plaisir à perfectionner.",
      
      ambiance: "Notre établissement vous accueille dans un cadre pensé pour votre confort et votre plaisir. L'atmosphère, la décoration, tout a été conçu pour vous offrir un moment d'exception.",
      
      upcoming_event: "Nos événements sont des occasions privilégiées de découvrir notre établissement sous un jour nouveau. Des moments de partage et de convivialité que nous organisons avec passion.",
      
      location: "Notre emplacement unique vous offre une expérience particulière, au cœur d'un quartier qui ne manque pas de caractère. Une adresse à découvrir ou redécouvrir.",
      
      unique_selling_point: "Ce qui nous différencie, c'est notre approche personnalisée et notre attachement à certaines valeurs qui guident notre travail au quotidien."
    };
    
    // Get examples for the selected style and focus area
    const styleExample = styleExamples[style] || styleExamples.professional;
    const focusAreaExample = focusAreaExamples[focusArea] || focusAreaExamples.menu_highlights;
    
    // Build menu highlights section with FACTUAL information
    let menuSection = '';
    if (producer.menu_categories && producer.menu_categories.length > 0) {
      // Select a maximum of 3 items to highlight
      const highlightedItems = [];
      
      // First try to use top rated items if available
      if (producer.top_items && producer.top_items.length > 0) {
        producer.top_items.forEach(item => {
          if (highlightedItems.length < 3) {
            highlightedItems.push(`- ${item.name}${item.price ? ` (${item.price})` : ''}: ${item.description}`);
          }
        });
      }
      
      // If we still need more items, select from categories
      if (highlightedItems.length < 3) {
        for (const category of producer.menu_categories) {
          if (category.items && category.items.length > 0) {
            for (const item of category.items) {
              if (highlightedItems.length < 3 && item.name && item.description) {
                highlightedItems.push(`- ${item.name}${item.price ? ` (${item.price})` : ''}: ${item.description}`);
              }
            }
          }
          
          if (highlightedItems.length >= 3) break;
        }
      }
      
      if (highlightedItems.length > 0) {
        menuSection = `
        POINTS FORTS DU MENU:
        ${highlightedItems.join('\n')}
        `;
      }
    }
    
    // Build specialties section if applicable
    let specialtiesSection = '';
    if (producer.specialties && producer.specialties.length > 0) {
      specialtiesSection = `
      SPÉCIALITÉS:
      ${producer.specialties.join(', ')}
      `;
    }
    
    // Build upcoming events section if applicable
    let eventsSection = '';
    if (producer.upcoming_events && producer.upcoming_events.length > 0) {
      const eventItems = producer.upcoming_events
        .slice(0, 2)
        .map(event => `- ${event.name} (${event.date}): ${event.description.substring(0, 50)}...`);
      
      eventsSection = `
      ÉVÉNEMENTS À VENIR:
      ${eventItems.join('\n')}
      `;
    }
    
    // Construct the final prompt with FACTUAL information only
    return `
    Écris un post engageant pour un réseau social à propos de ce restaurant/établissement.
    
    DÉTAILS DE L'ÉTABLISSEMENT:
    Nom: ${producer.name}
    Localisation: ${producer.location}
    Catégorie: ${producer.category}
    Description: ${producer.description}
    ${producer.rating ? `Note moyenne: ${producer.rating}/5\n` : ''}
    ${producer.hours ? `Horaires: ${producer.hours}\n` : ''}
    ${menuSection}
    ${specialtiesSection}
    ${eventsSection}
    
    FOCUS DU POST: ${focusArea}
    STYLE DU POST: ${style}
    
    EXEMPLE DE CE STYLE:
    "${styleExample}"
    
    EXEMPLE DE CE FOCUS:
    "${focusAreaExample}"
    
    INSTRUCTIONS:
    - Le post doit être écrit en français
    - Ton ${style === 'professional' ? 'professionnel mais chaleureux' : 
           style === 'casual' ? 'décontracté et amical' : 
           style === 'enthusiastic' ? 'enthousiaste et énergique' : 
           style === 'elegant' ? 'élégant et raffiné' : 
           style === 'humorous' ? 'léger et humoristique' : 'conversationnel'}
    - Utiliser un langage varié et engageant
    - Entre 40 et 70 mots
    - Ne pas utiliser d'émojis ni de hashtags
    - Donner envie aux lecteurs de visiter l'établissement
    - Ne jamais inclure de texte générique comme [nom] ou [restaurant]
    - IMPORTANT: N'INVENTE AUCUNE INFORMATION qui n'est pas présente dans les détails fournis
    - N'invente pas de prix, de récompenses, de classements ou d'évaluations
    - Utilise uniquement les faits présentés dans les détails de l'établissement
    
    IMPORTANT: Réponds uniquement avec le texte du post, sans explications ni formatage supplémentaire.
    `;
  }
  
  /**
   * Build prompt for discovery post generation
   * @param {Object} user - User interest data
   * @param {Object} recommendation - Recommendation data
   * @returns {String} - Generated prompt
   */
  buildDiscoveryPrompt(user, recommendation) {
    // Extract key interests for targeting
    const userInterests = Object.entries(user.interests)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 5)
      .map(entry => entry[0])
      .join(', ');
    
    // Determine if it's a producer or event recommendation
    const isProducer = recommendation.type === 'producer';
    
    // Examples for different recommendation types
    const exampleByType = isProducer ? 
      "Si vous cherchez un restaurant qui allie cuisine méditerranéenne authentique et cadre chaleureux, ne cherchez plus ! Le Petit Olivier cache des trésors culinaires qui correspondent parfaitement à vos goûts." :
      "Votre intérêt pour la musique live et l'art contemporain fait de cet événement au Centre Pompidou un incontournable pour vous. Une soirée où performances musicales et installations visuelles se rencontrent.";
    
    // Construct the final prompt
    return `
    Écris un post personnalisé de découverte pour un utilisateur, basé sur ses intérêts et préférences.
    
    INTÉRÊTS DE L'UTILISATEUR:
    ${userInterests}
    
    RECOMMANDATION:
    Type: ${recommendation.type}
    Nom: ${recommendation.name}
    Localisation: ${recommendation.location}
    Catégorie: ${recommendation.category}
    Description: ${recommendation.description}
    
    STYLE DU POST: Personnalisé et basé sur les intérêts
    
    EXEMPLE:
    "${exampleByType}"
    
    INSTRUCTIONS:
    - Le post doit être écrit en français
    - Ton chaleureux et personnalisé
    - Expliquer pourquoi cette recommandation correspond aux intérêts de l'utilisateur
    - Utiliser un langage varié et engageant
    - Entre 40 et 70 mots
    - Ne pas utiliser d'émojis ni de hashtags
    - Ne jamais inclure de texte générique comme [nom] ou [lieu]
    - Éviter d'utiliser directement "basé sur vos intérêts" ou phrases similaires trop évidentes
    
    IMPORTANT: Réponds uniquement avec le texte du post, sans explications ni formatage supplémentaire.
    `;
  }
  
  /**
   * Call DeepSeek API to generate text
   * @param {String} prompt - The prompt to send to DeepSeek
   * @returns {Promise<String>} - Generated text
   */
  async callDeepSeekAPI(prompt) {
    try {
      console.log('📡 Calling DeepSeek API...');
      
      const response = await axios.post(this.serverUrl, {
        prompt,
        max_tokens: 300,
        temperature: 0.7,
        top_p: 0.95,
        api_key: this.apiKey
      }, {
        headers: {
          'Content-Type': 'application/json'
        },
        timeout: 30000 // 30 second timeout
      });
      
      if (response.data && response.data.text) {
        const generatedText = response.data.text.trim();
        console.log(`✅ DeepSeek API response received (${generatedText.length} chars)`);
        return generatedText;
      } else {
        console.error('❌ Invalid response format from DeepSeek API:', response.data);
        return null;
      }
    } catch (error) {
      console.error('❌ Error calling DeepSeek API:', error.message);
      
      // Provide fallback content in case of API failure
      const fallbackContent = {
        event: "Ne manquez pas cet événement exceptionnel ! Une occasion unique de découvrir des talents locaux dans un cadre intimiste.",
        producer: "Une cuisine authentique qui met en valeur des produits de saison sélectionnés avec soin. Une adresse à découvrir absolument !",
        discovery: "Voici une recommandation qui correspond parfaitement à vos intérêts. Une expérience qui promet de vous surprendre agréablement."
      };
      
      // Determine which fallback to use based on the prompt content
      if (prompt.includes('ÉVÉNEMENT')) {
        return fallbackContent.event;
      } else if (prompt.includes('ÉTABLISSEMENT')) {
        return fallbackContent.producer;
      } else {
        return fallbackContent.discovery;
      }
    }
  }
}

module.exports = AutoPostGenerator;