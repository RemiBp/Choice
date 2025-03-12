# Feed Enhancement and Automatic Post Generation Proposal

## Current Feed Structure

Based on our analysis of the backend code, the current feed implementation has the following characteristics:

1. **Data Sources:**
   - Posts are pulled from multiple MongoDB databases (choice_app, Restauration_Officielle, Loisir&Culture)
   - Different types of content: user posts, producer posts, events, and leisure venues

2. **Current Scoring Algorithm:**
   - Tag matching: +10 points for each matching tag between post and user interests
   - Trust circle: +25 points if the post author is in the user's trusted circle
   - Recency: Up to +20 points based on how recently the post was created (decreasing over time)

3. **User Interactions:**
   - The system tracks likes, choices (similar to bookmarking), comments, and interests
   - Interactions are stored bidirectionally (on both user and post/entity records)
   - Follower relationships between users and producers are maintained

## Feed Algorithm Improvement

We propose enhancing the feed algorithm with the following improvements:

### 1. Enhanced User Interest Profiling

```javascript
function buildUserInterestProfile(user) {
  const profile = {
    categories: {},
    locations: {},
    cuisines: {},
    eventTypes: {},
    timePreferences: {}
  };
  
  // Analyze past interactions (choices, interests, likes)
  // from user.interests, user.choices, user.liked_posts
  
  // Extract and weight categorical preferences
  // For example, from restaurant categories, event types
  
  // Analyze location patterns from choices and interests
  
  // Determine temporal patterns (when user engages with content)
  
  return profile;
}
```

### 2. Social Graph Integration

```javascript
function calculateSocialRelevance(user, post) {
  let score = 0;
  
  // Check direct connections
  if (user.following.includes(post.author_id)) {
    score += 30;
  }
  
  // Check for mutual connections
  const mutualConnections = countMutualConnections(user, post.author_id);
  score += mutualConnections * 5; // 5 points per mutual connection
  
  // Consider engagement of following users
  const followingEngagements = countFollowingEngagements(user, post);
  score += followingEngagements * 15; // 15 points per following user who engaged
  
  return score;
}
```

### 3. Location-Based Relevance

```javascript
function calculateLocationRelevance(user, post) {
  let score = 0;
  
  if (!user.location || !post.location) {
    return 0;
  }
  
  // Calculate distance between user and post location
  const distance = calculateDistance(
    user.location.coordinates,
    post.location.coordinates
  );
  
  // Apply exponential decay based on distance
  // Closer locations receive higher scores
  score = 100 * Math.exp(-0.1 * distance);
  
  // Bonus for locations user frequently visits
  if (userFrequentsLocation(user, post.location)) {
    score += 25;
  }
  
  return score;
}
```

### 4. Engagement Prediction

```javascript
function predictEngagement(user, post) {
  let score = 0;
  
  // Content type preference
  const contentTypeScore = getContentTypePreference(user, post.type);
  score += contentTypeScore;
  
  // Historical engagement with similar content
  const similarContentScore = analyzeSimilarContentEngagement(user, post);
  score += similarContentScore;
  
  // For event posts, consider timing relevance
  if (post.event_date) {
    const eventTimingScore = calculateEventTimingScore(post.event_date);
    score += eventTimingScore;
  }
  
  return score;
}
```

### 5. Content Diversity Mechanism

```javascript
function applyDiversityAdjustment(rankedPosts, user) {
  // Group posts by category/type
  const categorizedPosts = groupPostsByCategory(rankedPosts);
  
  // Calculate ideal distribution based on user preferences
  const targetDistribution = calculateTargetDistribution(user);
  
  // Re-rank posts to match target distribution while preserving
  // relative ranking within categories
  const rerankedPosts = redistributePosts(
    categorizedPosts,
    targetDistribution
  );
  
  // Inject some random high-quality discovery content
  return injectDiscoveryContent(rerankedPosts, user);
}
```

### 6. Contextual Relevance

```javascript
function calculateContextualRelevance(post, user) {
  let score = 0;
  
  // Time of day relevance
  const timeOfDay = getCurrentTimeOfDay();
  if (isRelevantTimeForContent(post, timeOfDay)) {
    score += 15;
  }
  
  // Day of week relevance
  const dayOfWeek = getCurrentDayOfWeek();
  if (isRelevantDayForContent(post, dayOfWeek)) {
    score += 10;
  }
  
  // Seasonal relevance
  const season = getCurrentSeason();
  if (isSeasonallyRelevant(post, season)) {
    score += 20;
  }
  
  return score;
}
```

### Integrated Scoring Function

```javascript
function calculateOverallScore(user, post) {
  const now = new Date();
  
  // Base score from current algorithm
  let score = calculatePostScore(user, post, now);
  
  // Enhanced scoring components
  const interestScore = calculateInterestScore(user, post);
  const socialScore = calculateSocialRelevance(user, post);
  const locationScore = calculateLocationRelevance(user, post);
  const engagementScore = predictEngagement(user, post);
  const contextualScore = calculateContextualRelevance(post, user);
  
  // Weight and combine all factors
  score += interestScore * 0.3 + 
          socialScore * 0.25 + 
          locationScore * 0.2 + 
          engagementScore * 0.15 + 
          contextualScore * 0.1;
  
  return score;
}
```

## Automatic Post Generation Implementation

We propose creating a system for automatically generating engaging posts leveraging DeepSeek for natural language generation.

### 1. Post Types and Templates

**Event Promotion Posts:**
- "Your friend [name] loved this [event_type] at [venue]. [engaging description]"
- "[event_name] is happening at [venue] this weekend! [engaging description]"
- "Looking for [event_category] plans? [event_name] at [venue] has been getting great reviews!"

**Restaurant/Leisure Venue Recommendation Posts:**
- "Have you tried [restaurant_name] yet? Their [popular_dish] is getting rave reviews!"
- "[venue_name] in [location] matches your interests in [user_interest]. Check it out!"
- "Your friend [name] made a great Choice at [venue_name]. [quote or description]"

**User Interest-Based Discovery Posts:**
- "Based on your interest in [interest], you might enjoy [recommendation]."
- "People with similar tastes are loving [venue/event]. Ready to discover something new?"

### 2. Implementation Strategy

#### 2.1 Auto-Post Generation Service

```javascript
const DeepSeekService = require('../services/deepSeekService');
const PostService = require('../services/postService');
const UserService = require('../services/userService');
const ProducerService = require('../services/producerService');
const EventService = require('../services/eventService');

class AutoPostGenerator {
  constructor() {
    this.deepSeek = new DeepSeekService();
    this.postService = new PostService();
    this.userService = new UserService();
    this.producerService = new ProducerService();
    this.eventService = new EventService();
  }
  
  async generateEventPosts() {
    // Find upcoming events worth promoting
    const events = await this.eventService.getUpcomingHighValueEvents();
    
    for (const event of events) {
      // Find users who might be interested based on profile and location
      const targetUsers = await this.userService.findUsersInterestedIn(event);
      
      if (targetUsers.length === 0) continue;
      
      // Select a template style based on event type
      const templateType = this.selectTemplateType(event);
      
      // Generate engaging post content using DeepSeek
      const postContent = await this.deepSeek.generateEventPost({
        event,
        templateType,
        userBase: targetUsers
      });
      
      // Create and store the post
      await this.postService.createAutomaticPost({
        content: postContent,
        event_id: event._id,
        target_type: 'event',
        target_id: event._id,
        automation_type: 'event_promotion',
        media: event.photos || []
      });
    }
  }
  
  async generateProducerPosts() {
    // Similar implementation for producer posts
  }
  
  async generateInterestBasedPosts() {
    // Similar implementation for interest-based discovery posts
  }
  
  selectTemplateType(entity) {
    // Logic to select diverse template types
    // to ensure variety in post styles
  }
}
```

#### 2.2 DeepSeek Integration Service

```javascript
class DeepSeekService {
  constructor() {
    this.apiKey = process.env.DEEPSEEK_API_KEY;
    this.serverUrl = process.env.DEEPSEEK_SERVER_URL;
  }
  
  async generateEventPost({ event, templateType, userBase }) {
    // Construct a detailed prompt based on event details
    const prompt = this.constructEventPrompt(event, templateType, userBase);
    
    // Call DeepSeek API via the server on vast.ai
    const response = await this.callDeepSeekAPI(prompt);
    
    // Process and sanitize the response
    return this.processDeepSeekResponse(response);
  }
  
  constructEventPrompt(event, templateType, userBase) {
    // Extract key event details
    const { name, venue, date, category, description, price } = event;
    
    // Extract audience insights
    const audienceInterests = this.analyzeAudienceInterests(userBase);
    
    return `
      Generate an engaging, conversational social media post about the following event. 
      The post should feel authentic, personal, and drive engagement.
      
      Event Name: ${name}
      Venue: ${venue}
      Date/Time: ${date}
      Category: ${category}
      Description: ${description}
      Price: ${price}
      
      Target Audience Interests: ${audienceInterests.join(', ')}
      
      Post Style: ${templateType === 'social_proof' ? 
        'Frame this as a recommendation from a friend who loved this event' : 
        templateType === 'discovery' ? 
        'Frame this as a new discovery that matches the user\'s interests' :
        'Frame this as an exciting upcoming event worth checking out'}
      
      The post should:
      1. Be conversational and authentic
      2. Use varied and engaging language (avoid repetitive phrasing)
      3. Include a clear value proposition
      4. Create FOMO (fear of missing out)
      5. Be between 30-80 words
      6. Not use hashtags or emojis (the app will add these)
      7. NEVER include placeholder text like [name] or [event] in the output
      
      Important: Generate ONLY the post text without any explanations or extra information.
    `;
  }
  
  async callDeepSeekAPI(prompt) {
    // Call to the DeepSeek API
    // This will go through your server running on vast.ai
    
    try {
      const response = await fetch(this.serverUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${this.apiKey}`
        },
        body: JSON.stringify({
          prompt,
          max_tokens: 200,
          temperature: 0.7
        })
      });
      
      if (!response.ok) {
        throw new Error(`DeepSeek API error: ${response.statusText}`);
      }
      
      const data = await response.json();
      return data.text;
    } catch (error) {
      console.error('Error calling DeepSeek API:', error);
      return 'Check out this amazing event coming up soon!'; // Fallback
    }
  }
  
  processDeepSeekResponse(response) {
    // Clean and validate the response
    // Remove any unwanted artifacts
    // Ensure the text meets our standards
    return response.trim();
  }
  
  analyzeAudienceInterests(userBase) {
    // Extract common interests from the target user base
    // to help DeepSeek generate relevant content
    const interests = {};
    
    userBase.forEach(user => {
      (user.liked_tags || []).forEach(tag => {
        interests[tag] = (interests[tag] || 0) + 1;
      });
    });
    
    // Return top 5 interests
    return Object.entries(interests)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 5)
      .map(entry => entry[0]);
  }
}
```

#### 2.3 Post Scheduling System

```javascript
class PostScheduler {
  constructor() {
    this.autoPostGenerator = new AutoPostGenerator();
  }
  
  async scheduleRoutine() {
    // Schedule event posts
    // Run daily to find upcoming events worth promoting
    cron.schedule('0 10 * * *', async () => {
      await this.autoPostGenerator.generateEventPosts();
    });
    
    // Schedule producer posts
    // Run 3 times a week
    cron.schedule('0 14 * * 1,3,5', async () => {
      await this.autoPostGenerator.generateProducerPosts();
    });
    
    // Schedule interest-based discovery posts
    // Run twice a week
    cron.schedule('0 16 * * 2,6', async () => {
      await this.autoPostGenerator.generateInterestBasedPosts();
    });
  }
  
  async generateImmediate(type, params) {
    // For admin-triggered immediate generation
    switch (type) {
      case 'event':
        return await this.autoPostGenerator.generateEventPosts(params);
      case 'producer':
        return await this.autoPostGenerator.generateProducerPosts(params);
      case 'interest':
        return await this.autoPostGenerator.generateInterestBasedPosts(params);
      default:
        throw new Error('Unknown post generation type');
    }
  }
}
```

#### 2.4 Producer Automatic Post Controls

```javascript
class ProducerAutoPoster {
  constructor(producerId) {
    this.producerId = producerId;
    this.deepSeek = new DeepSeekService();
    this.postService = new PostService();
    this.producerService = new ProducerService();
  }
  
  async updateSettings(settings) {
    // Update producer's automatic posting preferences
    await this.producerService.updateAutoPostSettings(this.producerId, settings);
  }
  
  async getSettings() {
    // Get current settings
    const producer = await this.producerService.getById(this.producerId);
    return producer.auto_post_settings || {
      enabled: false,
      frequency: 'weekly',
      focus_areas: ['menu', 'events', 'promotions'],
      tone: 'professional'
    };
  }
  
  async generatePost() {
    const producer = await this.producerService.getById(this.producerId);
    
    // Check if automatic posting is enabled
    if (!producer.auto_post_settings?.enabled) {
      return null;
    }
    
    // Get producer details for post generation
    const producerDetails = await this.producerService.getDetailsForPosting(this.producerId);
    
    // Generate post content using DeepSeek
    const postContent = await this.deepSeek.generateProducerPost({
      producer: producerDetails,
      settings: producer.auto_post_settings
    });
    
    // Create and publish the post
    return await this.postService.createAutomaticPost({
      content: postContent,
      user_id: null, // No user ID for producer auto-posts
      producer_id: this.producerId,
      target_type: 'producer',
      target_id: this.producerId,
      automation_type: 'producer_auto',
      media: producer.photos || []
    });
  }
}
```

### 3. Custom Prompt Development for DeepSeek

To ensure high-quality, engaging post generation, we'll develop custom prompts for DeepSeek that include:

1. **Detailed context and guidelines**:
   - Event details, restaurant information, or user interest profiles
   - Brand voice and tone specifications
   - Engagement goals and call-to-action requirements

2. **Structured output format**:
   - Clear structure for the generated posts
   - Length requirements (30-80 words for optimal mobile engagement)
   - Style and formatting specifications

3. **Examples of high-performing posts**:
   - Provide examples of successful posts for each category
   - Highlight desirable features (conversational tone, engaging descriptions)
   - Include "temperature" controls to balance creativity and consistency

```javascript
// Example base prompt template for event posts
const eventPromptTemplate = `
  Write an engaging social media post about the following event.
  The tone should be: {{tone}}
  
  EVENT DETAILS:
  Name: {{event_name}}
  Date: {{event_date}}
  Location: {{event_location}}
  Description: {{event_description}}
  Category: {{event_category}}
  
  TARGET AUDIENCE:
  - Interests: {{audience_interests}}
  - Demographics: {{audience_demographics}}
  
  POST STRUCTURE:
  - Write as if coming from: {{post_perspective}}
  - Mention FOMO (fear of missing out): {{include_fomo}}
  - Include social proof: {{include_social_proof}}
  - Include a question: {{include_question}}
  
  EXAMPLES OF SUCCESSFUL POSTS:
  {{examples}}
  
  The post should be {{min_length}}-{{max_length}} words and should feel authentic,
  conversational, and engaging. Avoid clichés, marketing speak, or overly formal language.
  
  IMPORTANT: Reply ONLY with the post text. Do not include explanations or formatting instructions.
`;
```

## Implementation Plan

### Phase 1: Feed Algorithm Enhancement (2 weeks)
1. Implement user interest profiling system
2. Enhance scoring function with social and location relevance
3. Add engagement prediction components
4. Test feed results with various user profiles and content types
5. Implement AB testing framework to measure engagement improvements

### Phase 2: Automatic Post Generation Foundation (3 weeks)
1. Set up DeepSeek integration with vast.ai server
2. Develop prompt templates for different post types
3. Create post scheduling system
4. Implement data extraction for post content (events, producers)
5. Build storage and presentation structure for auto-generated posts

### Phase 3: Producer Controls & Refinement (2 weeks)
1. Implement producer settings for automatic posts
2. Create dashboard for monitoring and approving generated content
3. Refine prompts based on engagement metrics
4. Implement content variety mechanisms
5. Test with selected producers and events

### Phase 4: Full Release & Optimization (Ongoing)
1. Roll out to all producers with opt-in setting
2. Implement feedback loops for improving generation quality
3. Monitor engagement metrics and refine algorithms
4. Expand post types and templates
5. Optimize scheduling and distribution

## Conclusion

This comprehensive approach to enhancing the feed and implementing automatic post generation will:

1. Dramatically improve user engagement through personalized, relevant content
2. Reduce the initial content gap for new users through high-quality automatic posts
3. Provide producers with a valuable tool for maintaining an active presence
4. Create a more dynamic, engaging experience throughout the application

The implementation leverages existing data structures and API capabilities while introducing new components where needed. By focusing on quality, relevance, and engagement, this solution will help drive user retention and satisfaction.