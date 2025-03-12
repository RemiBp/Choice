/**
 * Post Automation Integration
 * 
 * This file demonstrates how to integrate the automatic post generation
 * and enhanced feed algorithm with the existing backend.
 */

const cron = require('node-cron');
const mongoose = require('mongoose');
const express = require('express');

// Import the AutoPostGenerator
const AutoPostGenerator = require('./auto_post_generator');

// Import services for dependency injection
// These paths should match the actual backend structure
const UserService = require('../../choice_app/backend/services/userService');
const PostService = require('../../choice_app/backend/services/postService');
const ProducerService = require('../../choice_app/backend/services/producerService');
const EventService = require('../../choice_app/backend/services/eventService');

// Configuration for the vast.ai DeepSeek instance
const DEEPSEEK_SERVER_URL = 'https://79.116.152.57:39370/terminals/1';

/**
 * Post Automation Scheduler Service
 * 
 * Manages the scheduling of automatic post generation
 */
class PostAutomationScheduler {
  constructor(app) {
    this.app = app;
    
    // Initialize dependencies
    this.userService = new UserService();
    this.postService = new PostService();
    this.producerService = new ProducerService();
    this.eventService = new EventService();
    
    // Initialize the post generator with dependencies
    this.autoPostGenerator = new AutoPostGenerator({
      userService: this.userService,
      postService: this.postService,
      producerService: this.producerService,
      eventService: this.eventService
    });
    
    // Configuration
    this.config = {
      // How many days in advance to look for events
      eventLookAheadDays: 14,
      
      // Minimum rating for event auto-posts
      minEventRating: 4.0,
      
      // Maximum posts per batch
      maxPostsPerBatch: {
        events: 5,
        producers: 10,
        discovery: 20
      },
      
      // Schedule settings (cron format)
      schedules: {
        events: '0 10 * * *',        // Daily at 10:00 AM
        producers: '0 14 * * 1,3,5',  // Mon, Wed, Fri at 2:00 PM
        discovery: '0 16 * * 2,6'     // Tue, Sat at 4:00 PM
      }
    };
  }
  
  /**
   * Initialize and start all scheduled jobs
   */
  initialize() {
    console.log('🚀 Initializing post automation scheduler');
    
    // Set environment variables for DeepSeek
    process.env.DEEPSEEK_SERVER_URL = DEEPSEEK_SERVER_URL;
    
    // Schedule event posts (daily at 10:00 AM)
    this.scheduleEventPosts();
    
    // Schedule producer posts (Mon, Wed, Fri at 2:00 PM)
    this.scheduleProducerPosts();
    
    // Schedule discovery posts (Tue, Sat at 4:00 PM)
    this.scheduleDiscoveryPosts();
    
    console.log('✅ Post automation scheduler initialized');
    
    // Setup routes for manual triggers and management
    this.setupRoutes();
  }
  
  /**
   * Schedule automatic event posts
   */
  scheduleEventPosts() {
    console.log(`📅 Scheduling event posts: ${this.config.schedules.events}`);
    
    cron.schedule(this.config.schedules.events, async () => {
      try {
        console.log('⏰ Running scheduled event post generation');
        
        // IMPORTANT: Only select events that haven't ended
        const today = new Date();
        
        const result = await this.autoPostGenerator.generateEventPosts({
          daysAhead: this.config.eventLookAheadDays,
          minRating: this.config.minEventRating,
          limit: this.config.maxPostsPerBatch.events,
          // Make sure we don't post about past events
          filterEndDate: today
        });
        
        console.log(`✅ Generated ${result.generated} event posts`);
        
        // Log detailed results
        this.logGenerationResults('event', result);
      } catch (error) {
        console.error('❌ Error in scheduled event post generation:', error);
      }
    });
  }
  
  /**
   * Schedule automatic producer posts
   */
  scheduleProducerPosts() {
    console.log(`📅 Scheduling producer posts: ${this.config.schedules.producers}`);
    
    cron.schedule(this.config.schedules.producers, async () => {
      try {
        console.log('⏰ Running scheduled producer post generation');
        
        const result = await this.autoPostGenerator.generateProducerPosts({
          limit: this.config.maxPostsPerBatch.producers
        });
        
        console.log(`✅ Generated ${result.generated} producer posts`);
        
        // Log detailed results
        this.logGenerationResults('producer', result);
      } catch (error) {
        console.error('❌ Error in scheduled producer post generation:', error);
      }
    });
  }
  
  /**
   * Schedule discovery posts
   */
  scheduleDiscoveryPosts() {
    console.log(`📅 Scheduling discovery posts: ${this.config.schedules.discovery}`);
    
    cron.schedule(this.config.schedules.discovery, async () => {
      try {
        console.log('⏰ Running scheduled discovery post generation');
        
        const result = await this.autoPostGenerator.generateDiscoveryPosts({
          minInteractions: 5,
          maxLastActivity: 7, // days
          limit: this.config.maxPostsPerBatch.discovery
        });
        
        console.log(`✅ Generated ${result.generated} discovery posts`);
        
        // Log detailed results
        this.logGenerationResults('discovery', result);
      } catch (error) {
        console.error('❌ Error in scheduled discovery post generation:', error);
      }
    });
  }
  
  /**
   * Log detailed results of post generation
   * @param {String} type - Type of posts generated
   * @param {Object} result - Generation results
   */
  logGenerationResults(type, result) {
    if (!result.posts || result.posts.length === 0) {
      console.log(`No ${type} posts were generated in this run`);
      return;
    }
    
    console.log(`📊 ${type.toUpperCase()} POST GENERATION RESULTS:`);
    console.log(`Generated: ${result.generated} posts`);
    
    // Log summary of each post
    result.posts.forEach((post, index) => {
      console.log(`${index + 1}. ${post.target_name || 'Unnamed'}: ${post.content.substring(0, 50)}...`);
    });
  }
  
  /**
   * Setup routes for manual control of post generation
   */
  setupRoutes() {
    const router = require('express').Router();
    
    // Route to manually trigger post generation
    router.post('/generate/:type', async (req, res) => {
      try {
        const { type } = req.params;
        const options = req.body || {};
        
        console.log(`🔄 Manual trigger for ${type} post generation with options:`, options);
        
        // IMPORTANT: Only generate posts for events that haven't ended
        if (type === 'event') {
          options.filterEndDate = new Date(); // Ensure we don't post about past events
        }
        
        let result;
        switch (type) {
          case 'event':
            result = await this.autoPostGenerator.generateEventPosts(options);
            break;
          case 'producer':
            result = await this.autoPostGenerator.generateProducerPosts(options);
            break;
          case 'discovery':
            result = await this.autoPostGenerator.generateDiscoveryPosts(options);
            break;
          default:
            return res.status(400).json({ 
              error: 'Invalid post type. Use: event, producer, or discovery' 
            });
        }
        
        res.status(200).json({
          message: `Generated ${result.generated} ${type} posts`,
          posts: result.posts,
          metadata: {
            generated_count: result.generated,
            timestamp: new Date().toISOString(),
            options: options
          }
        });
      } catch (error) {
        console.error('❌ Error in manual post generation:', error);
        res.status(500).json({ 
          error: 'Failed to generate posts',
          details: error.message
        });
      }
    });
    
    // Route to update producer auto-post settings
    router.put('/settings/producer/:producerId', async (req, res) => {
      try {
        const { producerId } = req.params;
        const settings = req.body;
        
        console.log(`🔄 Updating auto-post settings for producer ${producerId}:`, settings);
        
        // Validate the settings
        if (!settings || typeof settings !== 'object') {
          return res.status(400).json({ error: 'Invalid settings object' });
        }
        
        // Update the producer's settings
        const updatedProducer = await this.producerService.updateAutoPostSettings(
          producerId,
          settings
        );
        
        res.status(200).json({
          message: 'Auto-post settings updated successfully',
          producer: {
            _id: updatedProducer._id,
            name: updatedProducer.name,
            auto_post_settings: updatedProducer.auto_post_settings
          }
        });
      } catch (error) {
        console.error('❌ Error updating producer auto-post settings:', error);
        res.status(500).json({ 
          error: 'Failed to update settings',
          details: error.message
        });
      }
    });
    
    // Route to get producer auto-post settings
    router.get('/settings/producer/:producerId', async (req, res) => {
      try {
        const { producerId } = req.params;
        
        // Get the producer's settings
        const producer = await this.producerService.getById(producerId);
        
        if (!producer) {
          return res.status(404).json({ error: 'Producer not found' });
        }
        
        res.status(200).json({
          producer: {
            _id: producer._id,
            name: producer.name,
            auto_post_settings: producer.auto_post_settings || {
              enabled: false,
              frequency: 'weekly',
              focus_areas: ['menu', 'events', 'promotions'],
              tone: 'professional'
            }
          }
        });
      } catch (error) {
        console.error('❌ Error getting producer auto-post settings:', error);
        res.status(500).json({ 
          error: 'Failed to get settings',
          details: error.message
        });
      }
    });
    
    // Register the routes with the app
    this.app.use('/api/auto-posts', router);
    console.log('🛣️ Post automation routes registered');
  }
}

/**
 * Enhanced Feed Algorithm Integration
 * 
 * This class integrates the enhanced feed algorithm with the existing feed routes
 */
class EnhancedFeedAlgorithm {
  /**
   * Initialize the enhanced feed algorithm
   * @param {Object} router - Express router to extend
   */
  constructor(router) {
    this.router = router;
    this.setupRoutes();
  }
  
  /**
   * Setup enhanced feed routes
   */
  setupRoutes() {
    // Enhanced feed route
    this.router.get('/enhanced', async (req, res) => {
      const { userId, limit = 10, page = 1 } = req.query;
      
      if (!userId) {
        return res.status(400).json({ error: 'User ID is required' });
      }
      
      try {
        // Get the user
        const usersCollection = req.app.locals.db.usersCollection;
        const user = await usersCollection.findOne({ _id: userId });
        
        if (!user) {
          return res.status(404).json({ error: 'User not found' });
        }
        
        // Get posts from different collections
        const postsDbChoice = mongoose.connection.useDb('choice_app');
        const postsDbRest = mongoose.connection.useDb('Restauration_Officielle');
        const postsDbLoisir = mongoose.connection.useDb('Loisir&Culture');
        
        const PostChoice = postsDbChoice.model('Post', new mongoose.Schema({}, { strict: false }), 'Posts');
        const PostRest = postsDbRest.model('Post', new mongoose.Schema({}, { strict: false }), 'Posts');
        const PostLoisir = postsDbLoisir.model('Post', new mongoose.Schema({}, { strict: false }), 'Posts');
        
        // Fetch posts from both collections
        const [postsChoice, postsRest, postsLoisir] = await Promise.all([
          PostChoice.find()
            .sort({ posted_at: -1 })
            .skip((page - 1) * limit)
            .limit(parseInt(limit) * 2) // Fetch more to allow for sorting
            .lean(),
          PostRest.find()
            .sort({ posted_at: -1 })
            .skip((page - 1) * limit)
            .limit(parseInt(limit) * 2) // Fetch more to allow for sorting
            .lean(),
          PostLoisir.find()
            .sort({ posted_at: -1 })
            .skip((page - 1) * limit)
            .limit(parseInt(limit) * 2) // Fetch more to allow for sorting
            .lean(),
        ]);
        
        console.log(`📦 Found ${postsChoice.length} choice posts, ${postsRest.length} restaurant posts, and ${postsLoisir.length} leisure posts`);
        
        // Filter out posts for events that have already ended
        const today = new Date();
        const filteredPosts = [...postsChoice, ...postsRest, ...postsLoisir].filter(post => {
          // Skip filtering if it's not an event post
          if (post.target_type !== 'event' && !post.event_id) {
            return true;
          }
          
          // Check if the event has an end date
          const eventEndDate = post.event_end_date || post.date_fin || null;
          
          // If no end date, keep the post
          if (!eventEndDate) {
            return true;
          }
          
          // Keep only if event hasn't ended
          return new Date(eventEndDate) >= today;
        });
        
        // Combine posts and apply enhanced scoring
        const scoredPosts = this.applyEnhancedScoring(filteredPosts, user);
        
        // Apply diversity adjustments to ensure a varied feed
        const diversifiedPosts = this.applyDiversityAdjustment(scoredPosts, user);
        
        // Limit to requested number of posts
        const finalPosts = diversifiedPosts.slice(0, limit);
        
        res.json({
          posts: finalPosts,
          page: parseInt(page),
          limit: parseInt(limit),
          total: filteredPosts.length,
          has_more: filteredPosts.length > parseInt(page) * parseInt(limit)
        });
        
      } catch (error) {
        console.error('❌ Error generating enhanced feed:', error);
        res.status(500).json({ 
          error: 'Error generating feed',
          details: error.message
        });
      }
    });
    
    console.log('🛣️ Enhanced feed route registered at /api/posts/enhanced');
  }
  
  /**
   * Apply enhanced scoring algorithm to posts
   * @param {Array} posts - Posts to score
   * @param {Object} user - User to personalize for
   * @returns {Array} - Scored posts
   */
  applyEnhancedScoring(posts, user) {
    const now = new Date();
    const scoredPosts = [];
    
    for (const post of posts) {
      // Calculate base score
      let score = this.calculateBaseScore(user, post, now);
      
      // Calculate additional score components
      const interestScore = this.calculateInterestScore(user, post);
      const socialScore = this.calculateSocialRelevance(user, post);
      const locationScore = this.calculateLocationRelevance(user, post);
      const engagementScore = this.predictEngagement(user, post);
      const contextualScore = this.calculateContextualRelevance(post, user);
      
      // Combine scores with appropriate weights
      score += interestScore * 0.3 + 
              socialScore * 0.25 + 
              locationScore * 0.2 + 
              engagementScore * 0.15 + 
              contextualScore * 0.1;
      
      // Add calculated score to post
      scoredPosts.push({
        ...post,
        relevance_score: score,
        score_components: {
          base: this.calculateBaseScore(user, post, now),
          interest: interestScore,
          social: socialScore,
          location: locationScore,
          engagement: engagementScore,
          contextual: contextualScore
        }
      });
    }
    
    // Sort by score (descending)
    return scoredPosts.sort((a, b) => b.relevance_score - a.relevance_score);
  }
  
  /**
   * Calculate base score from current algorithm
   * @param {Object} user - User object
   * @param {Object} post - Post object
   * @param {Date} now - Current date
   * @returns {Number} - Base score
   */
  calculateBaseScore(user, post, now) {
    let score = 0;

    // Tag matching
    const tagsMatched = post.tags?.filter((tag) => 
      user.liked_tags?.includes(tag)).length || 0;
    score += tagsMatched * 10;

    // Trust circle
    if (user.trusted_circle?.includes(post.user_id || post.author_id)) {
      score += 25;
    }

    // Recency bonus
    const hoursSincePosted = (now - new Date(post.posted_at || post.time_posted)) / (1000 * 60 * 60);
    score += Math.max(0, 20 - hoursSincePosted);

    return score;
  }
  
  /**
   * Calculate interest score based on user preferences
   * @param {Object} user - User object
   * @param {Object} post - Post object
   * @returns {Number} - Interest score
   */
  calculateInterestScore(user, post) {
    let score = 0;
    
    // Match post content against user interests
    const userInterests = user.liked_tags || [];
    const postTags = post.tags || [];
    const postContent = post.content || '';
    
    // Direct tag matches
    const tagMatches = postTags.filter(tag => userInterests.includes(tag)).length;
    score += tagMatches * 15;
    
    // Content analysis for interests (simplified)
    userInterests.forEach(interest => {
      if (postContent.toLowerCase().includes(interest.toLowerCase())) {
        score += 5;
      }
    });
    
    // Category preferences
    if (post.category) {
      const categories = Array.isArray(post.category) ? post.category : [post.category];
      const categoryMatches = categories.filter(category => 
        userInterests.includes(category)).length;
      score += categoryMatches * 10;
    }
    
    // Special handling for event categories in Loisir&Culture
    if (post.catégorie) {
      const categories = Array.isArray(post.catégorie) ? post.catégorie : [post.catégorie];
      
      // Extract main categories from possibly complex strings
      const mainCategories = categories.map(cat => {
        // Handle format like "Théâtre » Comédie » Comédie satirique"
        if (cat.includes('»')) {
          return cat.split('»')[0].trim();
        }
        return cat;
      });
      
      const categoryMatches = mainCategories.filter(category => 
        userInterests.some(interest => 
          category.toLowerCase().includes(interest.toLowerCase()) || 
          interest.toLowerCase().includes(category.toLowerCase())
        )
      ).length;
      
      score += categoryMatches * 10;
    }
    
    return score;
  }
  
  /**
   * Calculate social relevance based on user connections
   * @param {Object} user - User object
   * @param {Object} post - Post object
   * @returns {Number} - Social relevance score
   */
  calculateSocialRelevance(user, post) {
    let score = 0;
    
    // Direct connection
    const following = user.following || [];
    const authorId = post.user_id || post.author_id;
    
    if (authorId && following.some(id => id.toString() === authorId.toString())) {
      score += 30;
    }
    
    // Engagement from followed users
    const postLikes = post.likes || [];
    const followingLikes = postLikes.filter(likeId => 
      following.some(id => id.toString() === likeId.toString())).length;
    
    score += followingLikes * 15;
    
    // Mutual connections (simplified)
    if (user.mutual_connections && authorId) {
      const mutualCount = user.mutual_connections[authorId] || 0;
      score += mutualCount * 5;
    }
    
    return score;
  }
  
  /**
   * Calculate location relevance
   * @param {Object} user - User object
   * @param {Object} post - Post object
   * @returns {Number} - Location relevance score
   */
  calculateLocationRelevance(user, post) {
    // Skip if location info is missing
    if (!user.location) {
      return 0;
    }
    
    // Check for location in different formats
    const postLocation = post.location || 
                         (post.coordinates ? { coordinates: post.coordinates } : null);
    
    if (!postLocation) {
      return 0;
    }
    
    let score = 0;
    
    // Calculate distance between user and post
    const userCoords = user.location.coordinates || [];
    const postCoords = postLocation.coordinates || [];
    
    if (userCoords.length >= 2 && postCoords.length >= 2) {
      const distance = this.calculateDistance(
        userCoords[0], userCoords[1],
        postCoords[0], postCoords[1]
      );
      
      // Apply exponential decay based on distance
      // Closer locations get higher scores
      score = 100 * Math.exp(-0.1 * distance);
    }
    
    // Check if location is among user's frequent locations
    if (user.frequent_locations && Array.isArray(user.frequent_locations)) {
      const locationName = postLocation.name || post.lieu || '';
      
      const isFrequent = user.frequent_locations.some(loc => 
        loc.name && loc.name.includes(locationName) || 
        locationName.includes(loc.name));
      
      if (isFrequent) {
        score += 25;
      }
    }
    
    return score;
  }
  
  /**
   * Predict engagement likelihood based on user history
   * @param {Object} user - User object
   * @param {Object} post - Post object
   * @returns {Number} - Predicted engagement score
   */
  predictEngagement(user, post) {
    let score = 0;
    
    // Content type preference
    const contentType = post.target_type || 
                      (post.producer_id ? 'producer' : 
                       post.event_id ? 'event' : 'user');
    
    // Analyze previous engagement with similar content
    const userLikes = user.liked_posts || [];
    const userChoices = user.choices || [];
    
    // Count engagements by content type
    let typeEngagementCount = 0;
    
    [...userLikes, ...userChoices].forEach(interaction => {
      const interactionType = interaction.target_type || 
                            (interaction.producer_id ? 'producer' : 
                             interaction.event_id ? 'event' : 'user');
      
      if (interactionType === contentType) {
        typeEngagementCount++;
      }
    });
    
    // Score based on previous engagement with this type
    score += Math.min(typeEngagementCount * 5, 40);
    
    // For event posts, consider timing relevance
    const eventDate = post.event_date || post.date_debut || post.prochaines_dates;
    if (eventDate) {
      let parsedDate;
      
      // Handle different date formats
      if (typeof eventDate === 'string') {
        if (eventDate.includes('/')) {
          // Format: DD/MM/YYYY
          const [day, month, year] = eventDate.split('/').map(part => parseInt(part, 10));
          parsedDate = new Date(year, month - 1, day);
        } else if (eventDate.includes('févr.') || eventDate.includes('janv.') || 
                  eventDate.includes('mars') || eventDate.includes('avr.')) {
          // Format: "sam 15 févr."
          const months = {
            'janv': 0, 'févr': 1, 'mars': 2, 'avr': 3, 'mai': 4, 'juin': 5,
            'juil': 6, 'août': 7, 'sept': 8, 'oct': 9, 'nov': 10, 'déc': 11
          };
          
          const parts = eventDate.split(' ');
          if (parts.length >= 3) {
            const day = parseInt(parts[1], 10);
            const monthStr = parts[2].replace('.', '');
            const month = months[monthStr];
            
            if (!isNaN(day) && month !== undefined) {
              const year = new Date().getFullYear();
              parsedDate = new Date(year, month, day);
            }
          }
        } else {
          // Try standard Date parsing
          parsedDate = new Date(eventDate);
        }
      } else {
        parsedDate = new Date(eventDate);
      }
      
      if (parsedDate && !isNaN(parsedDate.getTime())) {
        const now = new Date();
        const daysTillEvent = Math.ceil((parsedDate - now) / (1000 * 60 * 60 * 24));
        
        // Higher score for events happening soon (but not too soon)
        if (daysTillEvent > 0 && daysTillEvent <= 7) {
          score += 30 - (daysTillEvent * 3); // 30 for tomorrow, 27 for in 2 days, etc.
        }
      }
    }
    
    return score;
  }
  
  /**
   * Calculate contextual relevance based on time, day, season
   * @param {Object} post - Post object
   * @param {Object} user - User object
   * @returns {Number} - Contextual relevance score
   */
  calculateContextualRelevance(post, user) {
    let score = 0;
    
    const now = new Date();
    const hour = now.getHours();
    const dayOfWeek = now.getDay(); // 0 = Sunday, 6 = Saturday
    
    // Time of day relevance
    // Morning (6-11): breakfast, coffee, morning activities
    // Noon (11-14): lunch, restaurants
    // Afternoon (14-18): activities, culture
    // Evening (18-23): dinner, shows, nightlife
    // Night (23-6): late bars, clubs
    
    const contentHasTimeContext = this.hasTimeContext(post);
    if (contentHasTimeContext) {
      // Morning content
      if ((hour >= 6 && hour < 11) && 
          contentHasTimeContext.morning) {
        score += 15;
      }
      
      // Lunch content
      if ((hour >= 11 && hour < 14) && 
          contentHasTimeContext.lunch) {
        score += 15;
      }
      
      // Evening content
      if ((hour >= 18 && hour < 23) && 
          contentHasTimeContext.evening) {
        score += 15;
      }
    }
    
    // Weekend vs. weekday relevance
    const isWeekend = dayOfWeek === 0 || dayOfWeek === 6;
    
    if (isWeekend && this.isWeekendContent(post)) {
      score += 20;
    } else if (!isWeekend && this.isWeekdayContent(post)) {
      score += 15;
    }
    
    return score;
  }
  
  /**
   * Determine if content has time-of-day context
   * @param {Object} post - Post object
   * @returns {Object|null} - Time context flags
   */
  hasTimeContext(post) {
    const content = (post.content || post.description || post.détail || '').toLowerCase();
    const title = (post.title || post.intitulé || '').toLowerCase();
    const combined = content + ' ' + title;
    
    // Check for time-related keywords
    const morningKeywords = ['matin', 'petit-déjeuner', 'café', 'brunch'];
    const lunchKeywords = ['déjeuner', 'midi', 'lunch'];
    const eveningKeywords = ['soir', 'dîner', 'nuit', 'afterwork'];
    
    const hasMorning = morningKeywords.some(keyword => combined.includes(keyword));
    const hasLunch = lunchKeywords.some(keyword => combined.includes(keyword));
    const hasEvening = eveningKeywords.some(keyword => combined.includes(keyword));
    
    if (hasMorning || hasLunch || hasEvening) {
      return {
        morning: hasMorning,
        lunch: hasLunch,
        evening: hasEvening
      };
    }
    
    // Check for specific event timing in event_date or horaires
    if (post.horaires && post.horaires.length > 0 && post.horaires[0].heure) {
      const timeStr = post.horaires[0].heure;
      
      if (timeStr.includes('-')) {
        const startTime = timeStr.split('-')[0].trim();
        const hour = parseInt(startTime.split(':')[0], 10);
        
        if (hour >= 6 && hour < 11) {
          return { morning: true, lunch: false, evening: false };
        } else if (hour >= 11 && hour < 14) {
          return { morning: false, lunch: true, evening: false };
        } else if (hour >= 18 && hour < 23) {
          return { morning: false, lunch: false, evening: true };
        }
      }
    }
    
    // Standard event date check
    if (post.event_date || post.date_debut) {
      const date = new Date(post.event_date || post.date_debut);
      const eventHour = date.getHours();
      
      if (eventHour >= 6 && eventHour < 11) {
        return { morning: true, lunch: false, evening: false };
      } else if (eventHour >= 11 && eventHour < 14) {
        return { morning: false, lunch: true, evening: false };
      } else if (eventHour >= 18 && eventHour < 23) {
        return { morning: false, lunch: false, evening: true };
      }
    }
    
    return null;
  }
  
  /**
   * Check if content is weekend-oriented
   * @param {Object} post - Post object
   * @returns {Boolean} - True if weekend content
   */
  isWeekendContent(post) {
    const content = (post.content || post.description || post.détail || '').toLowerCase();
    const title = (post.title || post.intitulé || '').toLowerCase();
    const combined = content + ' ' + title;
    
    const weekendKeywords = ['weekend', 'samedi', 'dimanche', 'fin de semaine'];
    
    // Check horaires for weekend days
    if (post.horaires && post.horaires.length > 0) {
      const weekendDays = post.horaires.filter(h => 
        h.jour && (h.jour.toLowerCase().includes('sam') || h.jour.toLowerCase().includes('dim')));
      
      if (weekendDays.length > 0) {
        return true;
      }
    }
    
    return weekendKeywords.some(keyword => combined.includes(keyword));
  }
  
  /**
   * Check if content is weekday-oriented
   * @param {Object} post - Post object
   * @returns {Boolean} - True if weekday content
   */
  isWeekdayContent(post) {
    const content = (post.content || post.description || post.détail || '').toLowerCase();
    const title = (post.title || post.intitulé || '').toLowerCase();
    const combined = content + ' ' + title;
    
    const weekdayKeywords = ['semaine', 'lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi'];
    
    // Check horaires for weekday days
    if (post.horaires && post.horaires.length > 0) {
      const weekdayDays = post.horaires.filter(h => 
        h.jour && (h.jour.toLowerCase().includes('lun') || 
                  h.jour.toLowerCase().includes('mar') ||
                  h.jour.toLowerCase().includes('mer') ||
                  h.jour.toLowerCase().includes('jeu') ||
                  h.jour.toLowerCase().includes('ven')));
      
      if (weekdayDays.length > 0) {
        return true;
      }
    }
    
    return weekdayKeywords.some(keyword => combined.includes(keyword));
  }
  
  /**
   * Apply diversity adjustment to avoid monotonous feed
   * @param {Array} rankedPosts - Scored and ranked posts
   * @param {Object} user - User to personalize for
   * @returns {Array} - Diversified posts
   */
  applyDiversityAdjustment(rankedPosts, user) {
    if (rankedPosts.length <= 3) {
      return rankedPosts; // Not enough posts to diversify
    }
    
    // Group posts by type/category
    const groupedPosts = this.groupPostsByType(rankedPosts);
    
    // Determine target distribution
    const targetDistribution = this.calculateTargetDistribution(user, groupedPosts);
    
    // Apply distribution while preserving ranking within groups
    return this.redistributePosts(groupedPosts, targetDistribution);
  }
  
  /**
   * Group posts by their type
   * @param {Array} posts - Posts to group
   * @returns {Object} - Grouped posts
   */
  groupPostsByType(posts) {
    const grouped = {
      producer: [],
      event: [],
      user: [],
      other: []
    };
    
    posts.forEach(post => {
      if (post.target_type === 'producer' || post.producer_id) {
        grouped.producer.push(post);
      } else if (post.target_type === 'event' || post.event_id || post.intitulé) {
        grouped.event.push(post);
      } else if (post.user_id) {
        grouped.user.push(post);
      } else {
        grouped.other.push(post);
      }
    });
    
    return grouped;
  }
  
  /**
   * Calculate target distribution of post types
   * @param {Object} user - User object
   * @param {Object} groupedPosts - Posts grouped by type
   * @returns {Object} - Target distribution percentages
   */
  calculateTargetDistribution(user, groupedPosts) {
    // Default distribution
    const distribution = {
      producer: 0.35, // 35%
      event: 0.35,    // 35%
      user: 0.25,     // 25%
      other: 0.05     // 5%
    };
    
    // Adjust based on user preferences if available
    if (user.engagement_stats) {
      const stats = user.engagement_stats;
      
      // Calculate total engagements
      const total = (stats.producer_engagements || 0) + 
                   (stats.event_engagements || 0) + 
                   (stats.user_engagements || 0) + 
                   (stats.other_engagements || 0);
      
      if (total > 0) {
        // Adjust distribution based on user engagement
        distribution.producer = (stats.producer_engagements || 0) / total;
        distribution.event = (stats.event_engagements || 0) / total;
        distribution.user = (stats.user_engagements || 0) / total;
        distribution.other = (stats.other_engagements || 0) / total;
        
        // Ensure some minimum representation
        distribution.producer = Math.max(distribution.producer, 0.15);
        distribution.event = Math.max(distribution.event, 0.15);
        distribution.user = Math.max(distribution.user, 0.1);
        
        // Normalize to sum to 1
        const sum = distribution.producer + distribution.event + 
                   distribution.user + distribution.other;
        
        distribution.producer /= sum;
        distribution.event /= sum;
        distribution.user /= sum;
        distribution.other /= sum;
      }
    }
    
    // Adjust for available content (can't exceed what we have)
    const totalPosts = Object.values(groupedPosts)
      .reduce((sum, posts) => sum + posts.length, 0);
    
    Object.keys(distribution).forEach(key => {
      const maxPossible = groupedPosts[key].length / totalPosts;
      distribution[key] = Math.min(distribution[key], maxPossible);
    });
    
    // Normalize again to sum to 1
    const sum = Object.values(distribution).reduce((s, v) => s + v, 0);
    
    Object.keys(distribution).forEach(key => {
      distribution[key] /= sum;
    });
    
    return distribution;
  }
  
  /**
   * Redistribute posts according to target distribution
   * @param {Object} groupedPosts - Posts grouped by type
   * @param {Object} distribution - Target distribution percentages
   * @returns {Array} - Redistributed posts
   */
  redistributePosts(groupedPosts, distribution) {
    const totalPosts = Object.values(groupedPosts)
      .reduce((sum, posts) => sum + posts.length, 0);
    
    // Calculate how many posts of each type
    const counts = {};
    Object.keys(distribution).forEach(key => {
      counts[key] = Math.round(totalPosts * distribution[key]);
    });
    
    // Ensure we don't exceed the total
    let countSum = Object.values(counts).reduce((sum, count) => sum + count, 0);
    
    if (countSum > totalPosts) {
      // Reduce counts proportionally
      const factor = totalPosts / countSum;
      Object.keys(counts).forEach(key => {
        counts[key] = Math.floor(counts[key] * factor);
      });
      
      // Adjust to match exactly
      countSum = Object.values(counts).reduce((sum, count) => sum + count, 0);
      let diff = totalPosts - countSum;
      
      if (diff > 0) {
        // Add remaining posts to most under-represented types
        const sortedTypes = Object.keys(distribution)
          .map(key => ({
            key,
            actual: counts[key] / totalPosts,
            target: distribution[key],
            diff: distribution[key] - (counts[key] / totalPosts)
          }))
          .sort((a, b) => b.diff - a.diff);
        
        for (let i = 0; i < diff; i++) {
          counts[sortedTypes[i % sortedTypes.length].key]++;
        }
      }
    }
    
    // Prepare interleaved result
    const result = [];
    const remainingByType = { ...counts };
    let typeIndex = 0;
    const types = Object.keys(groupedPosts);
    
    // Interleave posts by type
    while (result.length < totalPosts) {
      const type = types[typeIndex % types.length];
      
      if (remainingByType[type] > 0 && groupedPosts[type].length > 0) {
        result.push(groupedPosts[type].shift());
        remainingByType[type]--;
      }
      
      typeIndex++;
      
      // If we've gone through all types, check if we're done
      if (typeIndex % types.length === 0) {
        const remaining = Object.values(remainingByType).reduce((sum, count) => sum + count, 0);
        
        if (remaining === 0) {
          // Add any leftover posts at the end
          types.forEach(type => {
            result.push(...groupedPosts[type]);
          });
          
          break;
        }
      }
    }
    
    return result;
  }
  
  /**
   * Calculate distance between two points using Haversine formula
   * @param {Number} lat1 - Latitude of point 1
   * @param {Number} lon1 - Longitude of point 1
   * @param {Number} lat2 - Latitude of point 2
   * @param {Number} lon2 - Longitude of point 2
   * @returns {Number} - Distance in kilometers
   */
  calculateDistance(lat1, lon1, lat2, lon2) {
    const R = 6371; // Radius of the earth in km
    const dLat = this.deg2rad(lat2 - lat1);
    const dLon = this.deg2rad(lon2 - lon1);
    
    const a = 
      Math.sin(dLat/2) * Math.sin(dLat/2) +
      Math.cos(this.deg2rad(lat1)) * Math.cos(this.deg2rad(lat2)) * 
      Math.sin(dLon/2) * Math.sin(dLon/2);
    
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
    const distance = R * c; // Distance in km
    
    return distance;
  }
  
  /**
   * Convert degrees to radians
   * @param {Number} deg - Degrees
   * @returns {Number} - Radians
   */
  deg2rad(deg) {
    return deg * (Math.PI/180);
  }
}

/**
 * Integration with Express application
 * @param {Object} app - Express app
 */
function integrateWithApp(app) {
  console.log('🔄 Integrating post automation with app');
  
  // Set environment variables for DeepSeek
  process.env.DEEPSEEK_SERVER_URL = DEEPSEEK_SERVER_URL;
  
  // Initialize post automation scheduler
  const scheduler = new PostAutomationScheduler(app);
  scheduler.initialize();
  
  // Integrate enhanced feed algorithm with the existing posts router
  const postsRouter = findExistingRouter(app, '/api/posts') || express.Router();
  
  if (!findExistingRouter(app, '/api/posts')) {
    console.warn('⚠️ Could not find existing posts router, creating a new one');
    app.use('/api/posts', postsRouter);
  }
  
  const enhancedFeed = new EnhancedFeedAlgorithm(postsRouter);
  
  // Connect to the AI routes for post generation
  addAiRoutesForPostGeneration(app);
  
  console.log('✅ Post automation integration complete');
}

/**
 * Find an existing router in the app
 * @param {Object} app - Express app
 * @param {String} path - Router path
 * @returns {Object|null} - Router or null
 */
function findExistingRouter(app, path) {
  if (!app || !app._router || !app._router.stack) {
    return null;
  }
  
  const layer = app._router.stack.find(layer => 
    layer.route && layer.route.path === path ||
    layer.name === 'router' && layer.regexp.test(path)
  );
  
  return layer ? layer.handle : null;
}

/**
 * Add AI routes for post generation
 * @param {Object} app - Express app
 */
function addAiRoutesForPostGeneration(app) {
  try {
    // Check if AI routes already exist
    const aiRouter = findExistingRouter(app, '/api/ai') || express.Router();
    
    if (!findExistingRouter(app, '/api/ai')) {
      console.log('🔄 Creating AI routes for post automation');
      app.use('/api/ai', aiRouter);
    }
    
    // Add route for generating posts via AI
    aiRouter.post('/generate-posts/:type', async (req, res) => {
      const { type } = req.params;
      const options = req.body || {};
      
      try {
        // Create services and AutoPostGenerator instance
        const userService = new UserService();
        const postService = new PostService();
        const producerService = new ProducerService();
        const eventService = new EventService();
        
        const postGenerator = new AutoPostGenerator({
          userService,
          postService, 
          producerService,
          eventService
        });
        
        // Ensure we don't post about past events
        if (type === 'event') {
          options.filterEndDate = new Date();
        }
        
        let result;
        switch (type) {
          case 'event':
            result = await postGenerator.generateEventPosts(options);
            break;
          case 'producer':
            result = await postGenerator.generateProducerPosts(options);
            break;
          case 'discovery':
            result = await postGenerator.generateDiscoveryPosts(options);
            break;
          default:
            return res.status(400).json({ error: 'Invalid post type' });
        }
        
        res.json({
          success: true,
          message: `Generated ${result.generated} ${type} posts`,
          posts: result.posts,
          metadata: {
            timestamp: new Date().toISOString(),
            options: options
          }
        });
      } catch (error) {
        console.error(`❌ Error generating ${type} posts:`, error);
        res.status(500).json({
          success: false,
          error: error.message
        });
      }
    });
    
    console.log('✅ AI routes for post automation registered');
  } catch (error) {
    console.error('❌ Error adding AI routes:', error);
  }
}

module.exports = {
  integrateWithApp,
  PostAutomationScheduler,
  EnhancedFeedAlgorithm
};