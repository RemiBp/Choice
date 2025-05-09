# Choice App - Application Synthesis

## 1. Introduction: Purpose and Technology Stack

**Core Purpose:** CHOICE is a **next-generation mobile app that redefines how users discover and interact with local experiences—restaurants, wellness centers, and leisure activities—by combining deep social validation (through shared, authentic "Choices" and "Interests"), smart data aggregation, and powerful AI-powered insights.** It aims to be a dynamic hybrid of Instagram's social engagement and Yelp/TripAdvisor's review depth, but with an added layer of intelligent data enrichment. It's also designed as an **indispensable B2B toolkit for "Producers"** (establishment owners/managers), empowering them to manage their online presence, showcase offerings, engage directly with customers, and gain deep, actionable insights.

**Project Resources:**
*   **GitHub Repository (Main Application):** [https://github.com/RemiBp/Choice/](https://github.com/RemiBp/Choice/) 

The app fosters a community where:
*   **Users** share detailed post-experience reviews called "Choices" and express their aspirational "Interests" for future experiences. They explore a visually rich feed where these "Choices" from their network, content influenced by collective "Interests," producer posts, and AI-driven recommendations help them make informed decisions. This discovery is further enhanced by AI-driven data like estimated nutritional information or popularity scores for menu items.
*   **Producers** can actively manage their digital storefront, respond to customer feedback, and leverage powerful analytics (including heatmaps for on-live engagement) to dynamically adapt their services and marketing. For leisure producers, a key feature is the ability to **create, manage, and promote their own events directly within the app.**

**Technology Stack, Data Acquisition & Enrichment:**
*   **Frontend:** Developed using Flutter, providing a cross-platform mobile application.
*   **Backend:** A Node.js/Express API.
*   **Database:** MongoDB.
*   **Key Services:** Firebase (authentication, push notifications), Stripe (payments).
*   **Data Sourcing & AI-Enrichment Strategy:**
    *   **Initial Data Acquisition:** CHOICE leverages external APIs, such as **Google Maps Platform**, to gather foundational data for establishments (location, existing public reviews, opening hours).
    *   **Restaurant/Wellness AI Analysis:**
        *   AI modules analyze aggregated public reviews and producer-provided menus.
        *   The system extracts and highlights popular/signature menu items.
        *   It aims to provide users with **estimated carbon footprints and approximated calorie counts** for menu items, promoting informed and conscious consumption.
    *   **Leisure Event Aggregation:** Data for leisure events is sourced through **partnerships with event platforms and APIs**, supplementing events created directly by producers within the app.
    *   This multi-faceted approach ensures a rich, relevant, and constantly updated database of experiences.

**The "Choice" vs. "Interest" Ecosystem:**
Two central concepts drive the app's unique value proposition:
1.  **"Choice": A Validated Post-Experience Review.** This is the core of user-generated content, akin to a detailed, structured, and often visual Yelp/TripAdvisor review but shared within a social feed like Instagram. When a user visits an establishment or attends an event, they can create a "Choice." This involves ratings on multiple facets, details of consumed items (potentially informed by the AI-analyzed menu data), emotions, and comments. Location verification adds authenticity.
2.  **"Interest": A Pre-Experience Expression of Intent.** This signifies a user's desire to visit a place, attend an event, or try a specific offering in the future. It builds a dynamic map of aspirations, valuable for both users (wishlists, discovery) and producers (demand gauging, targeted offers).

This document provides a detailed analysis of the Choice App, focusing on the frontend architecture, user and producer screens, their functionalities, their connections with the backend API and MongoDB data structures, and importantly, **their collective potential in realizing the app's vision as a leading social-experience platform powered by intelligent data and genuine user contributions.** It is intended as a reference for developers to understand, maintain, and strategically evolve the project, particularly in enhancing UI/UX to fulfill these advanced functionalities and identify areas for backend integration to support currently non-functional UI elements.

## 2. Frontend Architecture (Flutter)

The frontend application is developed with Flutter.

-   **Entry Point**: `lib/main.dart` initializes the application, configures essential services (Firebase, DotEnv, EasyLocalization, Stripe), state providers (`Provider`), and navigation.
-   **Navigation**: Navigation is managed via `MaterialApp` with static named routes and `onGenerateRoute` for dynamic routes (e.g., profiles, entity details). `navigatorKey` is used for global navigation.
-   **State Management**: `Provider` is used for state management, notably for `AuthService`, `NotificationService`, `BadgeService`, `AnalyticsService`, `VoiceRecognitionService`, `ApiService`, and `UserModel`.
-   **Directory Structure**:
    -   `lib/screens/`: Contains widgets representing the different screens of the application.
    -   `lib/widgets/`: Contains reusable UI components.
    -   `lib/services/`: Contains business logic and interactions with external APIs and the backend.
    -   `lib/models/`: Contains data models used in the application.
    -   `lib/theme/`: Manages light and dark themes.
    -   `lib/utils/`: Utility functions.
-   **Internationalization**: Managed with `easy_localization`.

## 3. User Screens (`accountType: 'user'` or `'guest'`)

### 3.1. `LandingPage`
*   **Path**: Initial page if not authenticated.
*   **Purpose**: Onboarding users and producers, serving as the gateway to the Choice App ecosystem. It introduces the app's dual nature: a social discovery tool and a producer engagement platform.
*   **Key Functionalities**:
    *   Displays logo and application presentation.
    *   "Recover Account" section (Producer): This is crucial. For producers whose businesses might already be listed (e.g., via data import), this initiates a **profile claiming process**. They search for their establishment, and if found, proceed to `/recover` which involves providing justification/proof of ownership to gain control of the pre-existing producer account. If not found, they can be directed to a creation flow.
    *   "Log in as User" section.
    *   "Create Account" button: Directs users to appropriate registration flows (user, or various producer types).
*   **Potential & Social/Producer Utility**:
    *   First touchpoint to communicate the "Instagram x Yelp/TripAdvisor" vision.
    *   Could feature dynamic content showcasing trending "Choices" or "Interests."
*   **Key UI Elements & Potential Backend Gaps/Future Integrations**:
    *   **Producer Search in "Recover Account"**: `GET /api/unified/search?query={query}&type={producerType}` - Functional.
    *   **Claim Process Trigger (`/recover`)**: The frontend route exists. Backend for `/api/auth/recover-producer` needs to handle the logic for verifying submitted justification and associating the user with the producer account.
    *   **Direct Producer Login (after search results)**: `POST /api/auth/login-with-id` - Functional for direct login if credentials are known, but the primary flow for unmanaged profiles is claiming.
    *   **UI for Justification Submission**: Frontend on `/recover` needs UI to upload documents/provide text. Backend needs to store and process this.
*   **Backend Connections**:
    *   Producer search: `GET /api/unified/search?query={query}&type={producerType}`
    *   Direct producer login (via selection): `POST /api/auth/login-with-id` (body: `{ id: producerId }`)
*   **MongoDB Structure (Inferred)**:
    *   `producers` (in `restaurationDb`), `leisureProducers` (in `loisirsDb`), `wellnessPlaces` (in `beautyWellnessDb`): for search with fields like `name`, `type`, `address`, `_id`.

### 3.2. `LoginUserPage`
*   **Path**: `/login`
*   **Purpose**: Allows a user to log into their account.
*   **Key Functionalities**:
    *   Login form (email/password).
    *   "Forgot password?" link.
    *   Login button.
*   **Backend Connections**:
    *   `POST /api/auth/login` (body: `{ email, password }`)
*   **MongoDB Structure (Inferred)**:
    *   `users` (in `choiceAppDb`): verification of `email`, `passwordHash`.

### 3.3. `RegisterUserPage`
*   **Path**: `/register`
*   **Purpose**: Allows a new user to create a standard account.
*   **Key Functionalities**:
    *   Registration form (name, email, password, etc.).
    *   Field validation.
    *   Registration button.
*   **Backend Connections**:
    *   `POST /api/auth/register` or `POST /api/newuser/register`
*   **MongoDB Structure (Inferred)**:
    *   `users` (in `choiceAppDb`): creation of a new user document.

### 3.4. `ResetPasswordScreen`
*   **Path**: `/reset-password?token={token}` (via `onGenerateRoute`)
*   **Purpose**: Allows a user to reset their password after requesting a reset link.
*   **Key Functionalities**:
    *   Form to enter a new password.
    *   Password confirmation.
*   **Backend Connections**:
    *   `POST /api/auth/reset-password/{token}` (body: `{ newPassword }`)
*   **MongoDB Structure (Inferred)**:
    *   `users` (in `choiceAppDb`): updates the `passwordHash` for the user associated with the token.

### 3.5. `FeedScreen`
*   **Main Tab (Index 0)** for users.
*   **Purpose**: A dynamic and personalized social discovery hub, functioning like an **Instagram feed but populated with rich, experience-based "Choices" and aspirational "Interests"** instead of just photos. Its core algorithm (to be fully developed) should intelligently blend content based on:
    *   **Network Interests**: Highlighting places, events, or items that friends/close connections have expressed a desire to experience (e.g., "Alice is interested in Restaurant X").
    *   **Shared Choices (as Posts)**: Displaying the detailed, validated experiences that users in the network have explicitly chosen to share publicly (via the `createPost` option when creating a "Choice").
    *   **Producer Posts**: Announcements, offers, and updates from followed producers.
    *   **AI-driven Recommendations**: Suggestions based on the user's own past Choices, Interests, and interactions.
*   **Key Functionalities**:
    *   Displays a vertically scrollable feed of posts, user-generated "Choices" (with visuals, ratings, comments), and expressed "Interests."
    *   Prioritizes content from friends ("proches") and followed producers/users.
    *   Interactive elements: Like, comment, share buttons for "Choices," "Interests," and posts.
    *   Content filters (e.g., by type of experience, proximity, friend activity, trending).
*   **Potential & Social/Producer Utility**:
    *   **Social Discovery Engine**: "Choices" from friends act as powerful, trusted recommendations (akin to Yelp reviews from people you know, shared like an Insta post).
    *   **Interest-Driven Discovery**: Seeing "X is interested in this concert" can spark similar interest in their network.
    *   **AI-Powered Curation**: The feed is prime for AI personalization, learning from user's past "Choices," expressed "Interests," interaction patterns (taps, time spent), and social graph to surface hyper-relevant content.
    *   **Producer Visibility**: Positive "Choices" get amplified. Producers can create engaging posts (new dishes, upcoming events) and directly solicit "Interests" from users.
*   **Key UI Elements & Potential Backend Gaps/Future Integrations**:
    *   **Like/Comment/Share buttons**: `POST /api/interactions` - Assumed functional for posts. Needs to be verified/extended for "Choices" and "Interests" as distinct target types.
    *   **Filtering UI**: Frontend needs robust filter options. Backend needs to support these in feed aggregation logic (e.g., `GET /api/posts/feed/{userId}?filter=...`).
    *   **"Add to Interests" button on producer posts/profiles**: Frontend UI element. Backend: `POST /api/interests`.
    *   **Display of aggregated Choice ratings within feed items**: Frontend. Backend needs to provide this efficiently in the feed data.
*   **Backend Connections**:
    *   `GET /api/posts/feed/{userId}` (likely to be enhanced to include "Choices" and "Interests" from network)
    *   `GET /api/choices/user/{userId}/network` (new or modified endpoint for network's choices)
    *   `GET /api/interests/user/{userId}/network` (new endpoint for network's interests)
*   **MongoDB Structure (Inferred)**:
    *   `posts` (in `choiceAppDb`): content of posts, `userId` of the creator, `producerId`.
    *   `users` (in `choiceAppDb`): user information, their followings.
    *   `choices` (in `choiceAppDb`): user preferences and interactions.
    *   `interactions` (in `choiceAppDb`): logs of likes, comments, shares.

### 3.6. Map Screens (`MapRestaurantScreen`, `MapLeisureScreen`, `MapWellnessScreen`, `MapFriendsScreen`)
*   **Main Tab (Index 1)** for users, with a map type selector.
*   **Purpose**: Visual and geographical exploration, transforming the map from a utility into an **interactive social discovery layer for experiences (Choices) and aspirations (Interests).**
*   **Key Functionalities**:
    *   Interactive map with markers for places, events, and friends.
    *   Pop-ups on markers: Summaries, aggregated "Choice" ratings (e.g., star rating), number of "Interests," link to full profile/details.
    *   Search and dynamic filters (e.g., "Show restaurants with >4 stars based on friends' Choices," "Events my friends are Interested in").
*   **Potential & Social/Producer Utility**:
    *   **Visual Discovery of Social Proof**: "See where your friends loved eating" or "Places trending with high Interest in your area."
    *   **Real-time Hotspots**: Markers could visually adapt based on recent "Choice" activity or surges in "Interests."
    *   **Producer Benefit**: High-performing or high-interest establishments gain prominent visibility.
*   **Key UI Elements & Potential Backend Gaps/Future Integrations**:
    *   **Map Marker Pop-ups**: Frontend needs to display rich info. Backend API for map data (`GET /api/producers/map-choices-interests`) must provide aggregated ratings and Interest counts efficiently.
    *   **Advanced Filtering UI**: Frontend needs to implement these. Backend needs to support complex filtering on map data queries.
    *   **"Quick Interest" button on map pop-ups**: Frontend UI. Backend: `POST /api/interests`.
*   **Backend Connections**:
    *   Endpoints like `GET /api/producers/map-choices-interests` (new or enhanced) to fetch places along with aggregated "Choice" data and "Interest" counts for map display.
*   **MongoDB Structure (Inferred)**:
    *   Specific collections (`producers`, `leisureProducers`, `wellnessPlaces`) with geolocation fields (e.g., `location: { type: 'Point', coordinates: [lng, lat] }`), `name`, `type`, `address`.
    *   `users` (in `choiceAppDb`): for friends, with a `currentLocation` field.
    *   `locationHistory` (in `choiceAppDb`): to track movements (if friends heatmap).

### 3.7. `ProducerSearchPage`
*   **Main Tab (Index 2)** for users.
*   **Purpose**: Search for producers (restaurants, leisure, wellness) by name, category, etc.
*   **Key Functionalities**:
    *   Search bar.
    *   Filters (producer type, location, etc.).
    *   List of search results.
    *   Navigation to the producer's detail page.
*   **Backend Connections**:
    *   `GET /api/unified/search?query={searchText}&type={type}&filters...`
*   **MongoDB Structure (Inferred)**:
    *   `producers`, `leisureProducers`, `wellnessPlaces`: text search on `name`, `description`, `tags`, and filters on specific fields.

### 3.8. `CopilotScreen`
*   **Main Tab (Index 3)** for users.
*   **Purpose**: An AI-powered personal concierge that provides hyper-personalized recommendations by deeply understanding a user's validated experiences ("Choices") and expressed desires ("Interests"). It aims to be the **intelligent discovery engine of Choice App.**
*   **Key Functionalities**:
    *   Conversational AI interface for natural language queries (e.g., "Find a quiet cafe good for working, similar to the one I gave a 5-star 'Choice' to last week").
    *   Proactive suggestions (e.g., "Based on your 'Interest' in hiking and positive 'Choices' for outdoor gear shops...").
    *   Group planning assistance: "Find a restaurant you, Sarah, and John would all like, considering your mutual 'Interests' and past 'Choices'."
*   **Potential & Social/Producer Utility**:
    *   **Deep Personalization**: Goes beyond simple keyword matching to understand nuanced preferences from past structured "Choices."
    *   **Facilitates Conversion of "Interests"**: Reminds users or suggests actions related to their expressed "Interests."
    *   **Producer Benefit**: AI can subtly guide users who are a strong match for a producer's offerings, increasing the likelihood of a positive "Choice."
*   **Key UI Elements & Potential Backend Gaps/Future Integrations**:
    *   **Display of AI Reasoning**: UI to show *why* a suggestion is made (e.g., "Because you liked X and are interested in Y"). Backend AI service needs to provide these explanations.
    *   **Direct Action Buttons from AI Suggestions**: (e.g., "Book Table," "Add to Calendar," "Share with Sarah"). These would require integrations with respective backend services or frontend navigation.
    *   **Feedback on AI Suggestions**: Thumbs up/down on suggestions to further train the AI. Backend needs an endpoint to capture this feedback (`POST /api/ai/copilot/feedback`).
*   **Backend Connections**:
    *   `POST /api/ai/copilot` (would now take into account both `choices` and `interests` collections for its logic)
    *   `GET /api/ai/recommendations/{userId}` (recommendations become richer and more targeted)
*   **MongoDB Structure (Inferred)**:
    *   Uses data from `users` (preferences, history), `interactions`, `choices`, `posts`, `producers`, `leisureProducers`, `wellnessPlaces` to generate recommendations. May have a `copilotSessions` or `aiInteractions` collection.

### 3.9. `MyProfileScreen`
*   **Main Tab (Index 4)** for users.
*   **Direct Path**: `/profile/me`
*   **Purpose**: Manage one's own user profile.
*   **Key Functionalities**:
    *   Display profile information (name, photo, bio).
    *   Edit profile information.
    *   Manage account settings (notifications, privacy).
    *   View friends, posts, favorites.
    *   Log out.
    *   Toggle application theme (via `toggleTheme`).
*   **Backend Connections**:
    *   `GET /api/users/{userId}`
    *   `PUT /api/users/profile/update`
    *   `GET /api/preferences/{userId}`
    *   `PUT /api/preferences/{userId}`
*   **MongoDB Structure (Inferred)**:
    *   `users` (in `choiceAppDb`): read and update fields `name`, `profilePictureUrl`, `bio`, `settings`.
    *   `preferences` (in `choiceAppDb` or embedded in `users`).

### 3.10. `ProfileScreen`
*   **Dynamic Path**: `/profile?userId={userId}` (via `onGenerateRoute`)
*   **Purpose**: View the public profile of another user.
*   **Key Functionalities**:
    *   Display public profile information (name, photo, bio, number of friends, public posts).
    *   Option to add/remove as friend.
    *   Follow/Unfollow.
*   **Backend Connections**:
    *   `GET /api/users/{userId}/public`
    *   `POST /api/friends/request`
    *   `POST /api/users/follow`
*   **MongoDB Structure (Inferred)**:
    *   `users` (in `choiceAppDb`): read public fields.
    *   `friendships` (in `choiceAppDb`).
    *   `followers` (potentially a sub-collection or array in `users`).

### 3.11. `MessagingScreen`
*   **Path**: `/messaging`
*   **Purpose**: Allow users to communicate via private messages.
*   **Key Functionalities**:
    *   List of conversations.
    *   Display messages within a conversation.
    *   Send messages (text, images, GIFs via Tenor).
    *   New message notifications.
*   **Backend Connections**:
    *   `GET /api/conversations/{userId}`
    *   `GET /api/conversations/{conversationId}/messages`
    *   `POST /api/conversations/send` (or via WebSockets)
    *   WebSockets (configured in `backend/index.js`): for real-time reception (`io.on('connection', ...)` and `socket.on('join_conversation', ...)`).
*   **MongoDB Structure (Inferred)**:
    *   `conversations` (in `choiceAppDb`): `participants: [userId1, userId2]`, `lastMessage`, `timestamp`.
    *   `messages` (in `choiceAppDb`): `conversationId`, `senderId`, `content`, `timestamp`, `isRead`.

### 3.12. `LanguageSelectionScreen`
*   **Path**: Displayed on first launch before `LandingPage`.
*   **Purpose**: Allow the user to choose the application language on first launch.
*   **Key Functionalities**:
    *   List of supported languages.
    *   Saves selected language (locally via `SharedPreferences` and potentially on user profile).
*   **Backend Connections**:
    *   Optional: `PUT /api/users/preferences` to save language preferences on the server.
*   **MongoDB Structure (Inferred)**:
    *   `users` (in `choiceAppDb`): `locale` field in user preferences.

### 3.13. `VideoCallScreen`
*   **Purpose**: Enable video calls between users.
*   **Key Functionalities**:
    *   Display self and other participant's video stream.
    *   Call controls (mute, end call, switch camera).
*   **Backend Connections**:
    *   Signaling via WebSockets (for WebRTC).
    *   `POST /api/calls/initiate`
    *   `POST /api/calls/accept`
    *   `POST /api/calls/end`
*   **MongoDB Structure (Inferred)**:
    *   `calls` (in `choiceAppDb`): for call history (`callerId`, `receiverId`, `duration`, `isVideo`).

### 3.14. `ChoiceCreationScreen`
*   **Path**: Accessed via a prominent action button (e.g., floating action button on the main navigation or feed).
*   **Purpose**: Enables users to create a **detailed, structured, and potentially validated "Choice"** following an experience. This is the primary mechanism for generating high-quality, user-generated content that fuels the social and AI aspects of the app. It's designed for users to share authentic experiences, often with their close connections ("proches"). This screen operationalizes the "Yelp/TripAdvisor review quality with Instagram-like sharing" concept.
*   **Key Functionalities**:
    1.  **Type Selection**: User selects 'restaurant', 'event', or 'wellness'. This dictates subsequent rating criteria.
    2.  **Location Search & Selection**: User finds the establishment/event.
    3.  **Location Verification (Crucial for Authenticity)**:
        *   `POST /api/choices/verify`: Backend verifies if the user was plausibly at the location (e.g., recent presence via `locationHistory`). This step significantly boosts the credibility of "Choices."
    4.  **Multi-Facet Experience Rating**:
        *   **Restaurant**: Rates general aspects (service, place, ambiance); lists and individually rates **consumed items/menus** (fetched from producer's `structured_data` via `GET /api/producers/{placeId}`, potentially augmented with AI-derived insights like calorie estimates or popularity flags). This granular feedback on specific items is highly valuable.
        *   **Event**: Rates event-specific aspects (e.g., performance, organization) based on `_eventCategories`; selects **emotions** felt. (Events can be sourced from partner APIs or created directly by Leisure Producers).
        *   **Wellness**: Rates dynamic criteria (e.g., quality of care, cleanliness) defined by the producer (fetched from `criteria_ratings` via `GET /api/wellness/{placeId}`); selects **emotions** felt. (Offerings may be enriched with AI insights).
    5.  **Commentary & Optional Post Creation**: User can add a textual comment to their "Choice." They can also opt to make their "Choice" a public post, increasing its visibility.
    6.  **Submission**: `POST /api/choices` sends the rich data (ratings, consumed items, emotions, comment, etc.) to the backend.
*   **Potential & Social/Producer Utility**:
    *   **Foundation of Trust**: Verified "Choices" build credibility for the platform.
    *   **Rich Data for AI**: The structured nature of "Choices" (specific aspect ratings, consumed items) provides excellent data for AI recommendations and producer analytics.
    *   **Social Proof & Influence**: Sharing "Choices" with "proches" creates strong social proof.
    *   **Direct Producer Feedback Loop**: Producers receive detailed, itemized feedback (for restaurants) and sentiment analysis (via emotions and comments).
*   **Key UI Elements & Potential Backend Gaps/Future Integrations**:
    *   **Photo/Video Upload for Choices/Posts**: UI elements exist (implied by a social app). Backend needs robust file handling (e.g., `POST /api/media/upload`) and association with choices/posts.
    *   **Tagging Friends in Choices/Posts**: Common social feature. UI for friend selection. Backend to store tags and notify tagged users.
    *   **Privacy Settings for Choices/Posts**: (e.g., "Friends Only," "Public"). UI toggle. Backend to enforce this in feed generation and direct access.
    *   **Saving Draft Choices**: UI button. Backend endpoint `POST /api/choices/draft` and `PUT /api/choices/draft/{draftId}`.
*   **Backend Connections**:
    *   Location Search: (as per `LocationSearch` widget, typically `GET /api/unified/search` or similar).
    *   `POST /api/choices/verify` (body: `{ userId, locationId, locationType, location (user's current) }`)
    *   Restaurant Menu Fetch: `GET /api/producers/{placeId}` (to get `structured_data.Menus Globaux` and `structured_data.Items Indépendants`)
    *   Wellness Criteria Fetch: `GET /api/wellness/{placeId}` (to get `criteria_ratings`)
    *   `POST /api/choices` (body: detailed choice data as described above)
*   **MongoDB Structure (Inferred for `choices` collection in `choiceAppDb`)**:
    *   `_id`: ObjectId
    *   `userId`: ObjectId (ref to `users`)
    *   `locationId`: ObjectId (ref to `producers`, `leisureProducers`, or `wellnessPlaces` depending on `locationType`)
    *   `locationType`: String ('restaurant', 'event', 'wellness')
    *   `locationName`: String (denormalized for easier display)
    *   `ratings`: Object (e.g., `{"service": 4.5, "ambiance": 4.0}` or `{"Qualité des soins": 5.0}`)
    *   `consumedItems`: Array (for restaurants)
        *   `itemId`: String or ObjectId (from producer's menu data)
        *   `name`: String
        *   `type`: String ('menu' or 'item')
        *   `category`: String (optional, for items)
        *   `rating`: Number (0-5, can be null if not rated)
    *   `emotions`: Array of Strings (for events/wellness)
    *   `comment`: String (optional)
    *   `createPost`: Boolean
    *   `postId`: ObjectId (ref to `posts`, if `createPost` is true and a post is generated)
    *   `verifiedAt`: Date (timestamp of successful location verification)
    *   `createdAt`: Date
    *   `updatedAt`: Date

## 4. Producer Screens (`accountType: 'RestaurantProducer'`, `'LeisureProducer'`, `'WellnessProducer'`)

Producers use the app to manage their business presence, offerings, and interact with customer feedback, including aggregated data from "Choices" and expressed "Interests." Their active participation is key to the ecosystem's health. The producer side is their **command center for this new social-experience economy.**

### 4.1. Common Producer Screens

#### 4.1.1. `ProducerFeedScreen`
*   **Main Tab (Index 0)**.
*   **Purpose**: A real-time dashboard of customer sentiment and engagement, functioning like a **business-focused social media feed**. Allows producers to stay connected with their audience, monitor their reputation, and see how users are interacting with their brand and offerings.
*   **Key Functionalities**:
    *   View incoming "Choices," posts mentioning their establishment, comments, and reviews.
    *   Tools to directly respond to feedback (publicly or privately).
    *   See trends in "Interests" expressed for their offerings (e.g., "15 users added your new dish to their Interests this week").
*   **Potential & Social/Producer Utility**:
    *   **Direct Customer Relationship Management (CRM)**: Fosters loyalty and allows for quick resolution of issues highlighted in "Choices."
    *   **Content Ideation**: User-generated "Choices" provide authentic marketing material and inspiration for producer posts.
    *   **Demand Sensing**: Early indication of what customers are becoming "Interested" in, allowing proactive adjustments.
*   **Key UI Elements & Potential Backend Gaps/Future Integrations**:
    *   **Private Reply to a Choice/Comment**: UI button. Backend needs secure messaging endpoint for producer-to-user, linked to a specific Choice/comment (`POST /api/conversations/initiate-from-choice`).
    *   **Filter Feed by Sentiment/Rating**: UI controls. Backend feed aggregation needs to support this.
    *   **"Create Offer for Interested Users" button**: UI element. Backend: `POST /api/offers/targeted` using `interests` data.
*   **Backend Connections**:
    *   `GET /api/producer-feed/{producerId}` (enhanced to include "Interest" notifications)
    *   `GET /api/posts/producer/{producerId}`
    *   `GET /api/choices/producer/{producerId}`
    *   `GET /api/interests/producer/{producerId}` (new endpoint)

#### 4.1.2. `HeatmapScreen`
*   **Main Tab (Index 1)**.
*   **Purpose**: A powerful geo-analytical tool for producers to visualize customer activity, "Choice" hotspots, and "Interest" concentrations, enabling both strategic planning and **innovative real-time, on-premise operational adjustments.**
*   **Key Functionalities**:
    *   Displays map with overlays for "Choice" density, verified check-ins, user "Interest" expressions related to their location or specific offerings.
    *   Filters by time, specific offerings (e.g., "Show Interest for 'Vegan Pizza' in the last 24h").
*   **Potential & Social/Producer Utility**:
    *   **Strategic Insights**: Understand customer origins, popular zones within a venue, or where "Interests" are highest for targeted off-premise marketing.
    *   **"On-Live" Customer Engagement & Flow Management (Advanced Potential)**:
        *   **Real-time Hotspot/Coldspot Identification**: Producer monitors live activity/density on their premises via the app (requires users to opt-in to temporary, anonymized on-premise location sharing or check-ins).
        *   **Dynamic QR Code Offers**: If a zone shows low activity, or high "Interest" they want to convert *now*, the producer can generate a time-sensitive, hyper-local offer directly from the Heatmap interface.
        *   The app would generate a unique QR code. The producer displays this (e.g., on a tablet, small screen in that zone, or verbally communicated).
        *   Users on-site, seeing a prompt in *their* app (if nearby and opted-in) or by scanning the QR code, redeem an instant micro-incentive (e.g., "Free drink with next order in Zone B - valid 15 mins").
        *   This transforms the heatmap into an **active, on-premise yield management and customer experience enhancement tool, directly converting online interest/presence into offline action.**
*   **Key UI Elements & Potential Backend Gaps/Future Integrations**:
    *   **Live Mode Toggle**: UI for producers. Requires backend infrastructure for near real-time location updates from opted-in users on-premise.
    *   **"Generate Dynamic Offer QR" Button**: UI on heatmap. Backend: `POST /api/producers/dynamic-offer` needs to create offer, link to geo-fence/zone, generate QR, and set expiry.
    *   **User-side UI for On-Premise Prompts/QR Scanning**: Needs to be built in user app.
    *   **Redemption Tracking**: Backend to log redemptions of dynamic offers.
*   **Backend Connections**:
    *   `GET /api/heatmap/{producerId}` (backend logic would aggregate `locationHistory`, verified `choices`, and potentially `interests` with geo-tags)
    *   `POST /api/producers/dynamic-offer` (new endpoint for creating/managing these on-live QR code offers, linked to heatmap insights).

#### 4.1.3. `ProducerDashboardIaPage`
*   **Main Tab (Index 2)**.
*   **Purpose**: An AI-driven command center providing producers with actionable intelligence derived from "Choices," "Interests," market trends, and their own operational data. This is the **producer's strategic brain within Choice App.**
*   **Key Functionalities**:
    *   KPIs: Overall satisfaction from "Choices," "Interest" conversion rate, popular/unpopular items based on Choice ratings, sentiment trends from comments.
    *   AI-generated suggestions, e.g.:
        *   "Your 'Margherita Pizza' consistently gets 5-star ratings in 'Choices.' Feature it more prominently!"
        *   "Many users have expressed 'Interest' in 'gluten-free options,' but few 'Choices' reflect this. Consider adding some."
        *   "Negative sentiment in 'Choices' often mentions 'slow service' on Saturday evenings. Staffing adjustment needed?"
    *   Alerts for significant shifts in "Choice" patterns or "Interest" levels.
*   **Potential & Social/Producer Utility**:
    *   **Proactive Business Optimization**: AI helps make data-driven decisions on menu engineering, service improvements, marketing spend, operational changes.
    *   **Competitive Edge**: Understanding nuanced customer preferences and unmet "Interests" before competitors.
*   **Key UI Elements & Potential Backend Gaps/Future Integrations**:
    *   **Drill-down into AI Suggestions**: UI to see the underlying data/Choices that led to an AI insight.
    *   **"Implement Suggestion" Action Log**: UI for producer to mark AI suggestions they've acted on, to track effectiveness.
    *   **Comparative Analytics (Opt-in)**: UI/Backend to allow producers to (anonymously) compare certain performance metrics against local industry averages derived from the platform.
*   **Backend Connections**:
    *   `GET /api/ai/producer-dashboard/{producerId}` (AI logic now incorporates "Interests" data alongside "Choices")

#### 4.1.4. `GrowthAndReachScreen`
*   **Main Tab (Index 3)**.
*   **Purpose**: Track growth and reach metrics (new followers, post reach, profile views, trends from "Choices").
*   **Key Functionalities**:
    *   Charts and dashboards of performance metrics.
    *   Period comparisons.
*   **Backend Connections**:
    *   `GET /api/growth-analytics/{producerId}`
    *   `GET /api/stats/summary/{producerId}`
*   **MongoDB Structure (Inferred)**:
    *   `analyticsData` (dedicated collection or aggregation from `followers`, `views`, `interactions`, `choices`).

### 4.2. Screens Specific to Producer Type

#### 4.2.1. Restaurant Producer (`accountType: 'RestaurantProducer'`)

*   **`MyProducerProfileScreen` (Main Tab - Index 4)**
    *   **Purpose**: Manage the restaurant's digital storefront, critically including the detailed menu (`structured_data`) which is directly used by users in `ChoiceCreationScreen` when they specify and rate consumed items. Also, a place to define offerings (dishes, special menus) that users can express "Interest" in.
    *   **Key Functionalities**: Edit restaurant info, manage the menu (items with names, prices, descriptions, photos, categories - stored in `structured_data`), special offers, upcoming culinary events that users can mark as an "Interest."
    *   **Key UI Elements & Potential Backend Gaps/Future Integrations**:
        *   **Detailed Menu Management UI**: Robust UI for adding/editing nested menu items, categories, modifiers, photos per item. Current `structured_data` implies this; frontend needs to render it effectively.
        *   **"Mark as Special/New" Toggle for Menu Items**: UI flag. Backend to store this and potentially highlight in user-facing menus or feeds.
        *   **Stock Availability for Menu Items**: UI toggle. Backend `PUT /api/producers/{id}/menu/{itemId}/availability`.
    *   **Backend Connections**:
        *   `GET /api/producers/{producerId}`
        *   `PUT /api/producers/{producerId}/update` (or `PUT /api/producers/update` with ID in body)
        *   `GET /api/offers/producer/{producerId}`
        *   `POST /api/offers`
    *   **MongoDB Structure (Inferred)**:
        *   `producers` (in `restaurationDb`): fields like `name`, `address`, `cuisineType`, `openingHours`, `photos`, `ownerId`, `stripeAccountId`, and `structured_data: { "Menus Globaux": [], "Items Indépendants": [{ "catégorie": "...", "items": [{ "_id", "name", "price" }] }] }`.

*   **`ProducerScreen` (Route: `/restaurant/details/{producerId}`)**
    *   **Purpose**: Display public details of a restaurant (can also be viewed by users).
    *   **Key Functionalities**: View information, menu, photos, reviews (including "Choices").
    *   **Backend Connections**: `GET /api/producers/{producerId}`
    *   **MongoDB Structure (Inferred)**: `producers` (in `restaurationDb`).

*   **`RegisterRestaurantProducerPage` (Route: `/register-restaurant`)**
    *   **Purpose**: Allow registration of a new restaurant producer.
    *   **Key Functionalities**: Detailed registration form for restaurants.
    *   **Backend Connections**: `POST /api/auth/register-producer` (body: `{ ..., type: 'RestaurantProducer' }`) or `POST /api/producers/register`.
    *   **MongoDB Structure (Inferred)**: `producers` (in `restaurationDb`).

#### 4.2.2. Leisure Producer (`accountType: 'LeisureProducer'`)

*   **`MyProducerLeisureProfileScreen` (Main Tab - Index 4)**
    *   **Purpose**: Manage the leisure establishment's profile. Event details and specific activities entered here become targets for user "Choices" and "Interests."
    *   **Key Functionalities**: Edit info, manage events (details of which are rated in "Choices," including event category for nuanced rating aspects), pricing, and special activities or time slots that users can express "Interest" in.
    *   **Key UI Elements & Potential Backend Gaps/Future Integrations**:
        *   **Event Calendar Management UI**: More than just listing; a calendar view for scheduling recurring or one-off events.
        *   **Ticketing/Booking Info Fields**: UI fields for linking to external booking platforms or managing simple in-app expressions of intent to book (could tie into "Interests").
        *   **Capacity Management for Events/Activities**: UI fields. Backend to store and potentially display availability.
    *   **Backend Connections**:
        *   `GET /api/leisure-producers/{producerId}`
        *   `PUT /api/leisure-producers/{producerId}/update`
        *   `GET /api/events/producer/{producerId}`
        *   `POST /api/events`
    *   **MongoDB Structure (Inferred)**:
        *   `leisureProducers` (in `loisirsDb`): fields like `name`, `address`, `activityType`, `photos`, `pricing`.
        *   `events` (in `loisirsDb`): `producerId`, `title`, `description`, `date`, `time`, `price`, `category` (used by `ChoiceCreationScreen`).

*   **`ProducerLeisureScreen` (Route: `/leisure/details/{producerId}`)**
    *   **Purpose**: Display public details of a leisure producer.
    *   **Backend Connections**: `GET /api/leisure-producers/{producerId}`
    *   **MongoDB Structure (Inferred)**: `leisureProducers` (in `loisirsDb`).

*   **`EventLeisureScreen` (Route: `/leisure/event/{eventId}`)**
    *   **Purpose**: Display details of a specific leisure event.
    *   **Backend Connections**: `GET /api/events/{eventId}`
    *   **MongoDB Structure (Inferred)**: `events` (in `loisirsDb`).

*   **`RegisterLeisureProducerPage` (Route: `/register-leisure`)**
    *   **Purpose**: Registration of a new leisure producer.
    *   **Backend Connections**: `POST /api/auth/register-producer` (body: `{ ..., type: 'LeisureProducer' }`) or `POST /api/leisure-producers/register`.
    *   **MongoDB Structure (Inferred)**: `leisureProducers` (in `loisirsDb`).

#### 4.2.3. Wellness Producer (`accountType: 'WellnessProducer'`)

*   **`MyWellnessProducerProfileScreen` (Main Tab - Index 4)**
    *   **Purpose**: Manage the wellness center's profile. Crucially, this is where producers define the specific `criteria_ratings` (e.g., "Ambiance," "Expertise of Staff") that users will rate when creating a "Choice" for their establishment. They can also list services for "Interest" tracking.
    *   **Key Functionalities**: Edit info, manage service types, schedules, pricing, and define/update the `criteria_ratings` that form the basis of user "Choices." List specific treatments or classes (e.g., "Yoga Session Tuesday 6 PM") that users can express "Interest" in.
    *   **Key UI Elements & Potential Backend Gaps/Future Integrations**:
        *   **Service Customization UI**: Allowing producers to add/edit their unique services and the specific criteria they want rated for them (if going beyond global `criteria_ratings`).
        *   **Staff/Practitioner Profiles Linkage**: UI to list staff and link their profiles (if staff have user accounts or mini-profiles).
        *   **Appointment Booking Information/Integration**: Fields for booking links or basic availability display.
    *   **Backend Connections**:
        *   `GET /api/wellness/{producerId}`
        *   `PUT /api/wellness/{producerId}/update` (this is where `criteria_ratings` would be set/updated)
    *   **MongoDB Structure (Inferred)**:
        *   `wellnessPlaces` (in `beautyWellnessDb`): fields like `name`, `address`, `serviceTypes: []`, `photos`, `schedule`, `pricing`, and importantly `criteria_ratings: { "Criterion Display Name": "Default Value/Label", "average_score": null }`.

*   **`WellnessProducerScreen` (Route: `/wellness/details/{placeId}`)**
    *   **Purpose**: Display public details of a wellness establishment.
    *   **Backend Connections**: `GET /api/wellness/{placeId}`
    *   **MongoDB Structure (Inferred)**: `wellnessPlaces` (in `beautyWellnessDb`).

*   **`WellnessListScreen` (potentially used for search/discovery or management)**
    *   **Purpose**: List wellness establishments.
    *   **Backend Connections**: `GET /api/wellness/list`, `GET /api/wellness/search`
    *   **MongoDB Structure (Inferred)**: `wellnessPlaces` (in `beautyWellnessDb`).

*   **`RegisterWellnessProducerPage` (Route: `/register-wellness`)**
    *   **Purpose**: Registration of a new wellness producer.
    *   **Backend Connections**: `POST /api/auth/register-producer` (body: `{ ..., type: 'WellnessProducer' }`) or `POST /api/wellness/register`.
    *   **MongoDB Structure (Inferred)**: `wellnessPlaces` (in `beautyWellnessDb`).

### 4.3. `RecoverProducerPage`
*   **Path**: `/recover`
*   **Purpose**: Allow a producer to **claim a pre-existing unmanaged profile** for their establishment or recover access to an already managed account. This is vital for onboarding businesses that may already be in the system.
*   **Key Functionalities**:
    *   If claiming an unmanaged profile (identified from `LandingPage` search): Form to submit proof of ownership (e.g., business registration document upload, official email verification, phone call verification).
    *   If recovering a managed account: Standard password reset or account recovery mechanisms.
*   **Key UI Elements & Potential Backend Gaps/Future Integrations**:
    *   **File Upload UI for Proof of Ownership**: Frontend element. Backend needs secure file storage and a review queue/process for admin verification.
    *   **Status Tracking of Claim**: UI to show producer the status of their claim (Pending, Approved, More Info Needed). Backend state machine for claim status.
    *   **Admin Interface for Reviewing Claims**: Not in user-facing app, but essential backend/admin panel feature.
*   **Backend Connections**:
    *   `POST /api/auth/recover-producer` or a more specific `POST /api/auth/claim-producer-profile` (body: `{ producerId, justificationText, fileUploads[] }`).

## 5. Backend API Overview (Node.js / Express)

The backend is built with Node.js and Express, interacting with MongoDB. It uses multiple MongoDB databases to segment data by producer type (`restaurationDb`, `loisirsDb`, `beautyWellnessDb`) and a main database for common data (`choiceAppDb`), as configured via `backend/config/db.js` and utilized in `backend/models/index.js`.

The main file `backend/index.js` initializes the server, configures middlewares, establishes MongoDB connections, and mounts the various routes.

### Main Route Groups (in `backend/routes/`) and Associated Databases:

*   **`/api/auth`**: Authentication (login, register, reset password, recovery).
    *   **DB**: `choiceAppDb.users`, `restaurationDb.producers`, `loisirsDb.leisureProducers`, `beautyWellnessDb.wellnessPlaces`.
*   **`/api/users`**: User profile management, preferences.
    *   **DB**: `choiceAppDb.users`, `choiceAppDb.preferences`.
*   **`/api/producers`**: CRUD for restaurant producers. Includes fetching menu data (`structured_data`).
    *   **DB**: `restaurationDb.producers`.
*   **`/api/leisure-producers`**: CRUD for leisure producers.
    *   **DB**: `loisirsDb.leisureProducers`.
*   **`/api/wellness`**: CRUD for wellness producers. Includes fetching/updating `criteria_ratings`.
    *   **DB**: `beautyWellnessDb.wellnessPlaces`.
*   **`/api/events`**: Event management (mainly for leisure).
    *   **DB**: `loisirsDb.events`.
*   **`/api/posts`**: Post and feed management.
    *   **DB**: `choiceAppDb.posts`.
*   **`/api/choices`**: Core endpoint for creating "Choices" (`POST /api/choices`), verifying user location for a choice (`POST /api/choices/verify`), and fetching choices (`GET /api/choices/user/{userId}`, `GET /api/choices/producer/{producerId}`). **This is central to the user-generated experience content.**
    *   **DB**: `choiceAppDb.choices`, `choiceAppDb.locationHistory` (for verification).
*   **`/api/interactions`**: Logging generic interactions (likes, views, etc.) on posts, "Choices," and potentially "Interests."
    *   **DB**: `choiceAppDb.interactions`.
*   **`/api/unified`**: Unified search routes across producer types.
    *   **DB**: `restaurationDb.producers`, `loisirsDb.leisureProducers`, `beautyWellnessDb.wellnessPlaces`.
*   **`/api/ai`**: Endpoints for AI functionalities (user copilot, producer dashboard recommendations). **Crucially leverages both "Choices" (past validated experiences) and "Interests" (future desires), as well as externally sourced and AI-analyzed data (e.g., from Google Maps reviews, menu analysis for nutritional info/popularity, partner event feeds) for its models.**
    *   **DB**: Uses various collections for analysis, with `choices`, `interests`, producer data, and enriched external data being key inputs.
*   **`/api/stats`, `/api/growth-analytics`, `/api/heatmap`**: Analytical and statistical data for producers, **significantly enriched by aggregated "Choice" data, "Interest" trends, and insights from AI-analyzed content.**
    *   **DB**: `choiceAppDb.analyticsData` (or aggregation), `choiceAppDb.locationHistory`, `choiceAppDb.choices`, `choiceAppDb.interests`.
*   **`/api/conversations`, `/api/messages` (via WebSockets)**: Messaging system.
    *   **DB**: `choiceAppDb.conversations`, `choiceAppDb.messages`.
*   **`/api/friends`**: Management of friend relationships and associated data.
    *   **DB**: `choiceAppDb.users`, `choiceAppDb.friendships`, `choiceAppDb.locationHistory`.
*   **`/api/payments`, `/api/subscription`, `/api/premium-features`, `/stripe-webhooks`**: Payment, subscription, and premium feature management (Stripe integration).
    *   **DB**: `choiceAppDb.subscriptions`, `choiceAppDb.payments`.
*   **`/api/offers`**: Management of promotional offers by producers.
    *   **DB**: Potentially in each producer DB or a centralized `offers` collection with `producerId` and `producerType`.
*   **`/api/notifications`**: Push notification management.
    *   **DB**: `choiceAppDb.notificationTokens`, `choiceAppDb.notificationsLog`.
*   **`/api/producer-feed`**: Activity feed specific to producers.
    *   **DB**: Data aggregation.
*   **Socket.IO**: Used for real-time communication (messaging, notifications, potentially video call signaling). Manages "rooms" by `producerId` and `conversationId`.

### MongoDB Databases and Key Collections

Based on `backend/index.js` connections and the models defined in `backend/models/`, the MongoDB structure utilizes distinct databases for better data organization.

**Development MongoDB Connection URI:**
`mongodb+srv://freelancer_dev:ChoiceDev2025@lieuxrestauration.szq31.mongodb.net/?retryWrites=true&w=majority&appName=lieuxrestauration`
*(**Note**: This connection string provides direct database access and contains credentials. In a production environment, access should be strictly controlled, and connection strings managed securely via environment variables or a dedicated secrets management service.)*

1.  **`choiceAppDb` (Core User & Interaction Data)**
    *   **Purpose**: Stores central user information, social graph data, core content types (Choices, Posts, Interactions), communication features, and potentially shared analytics/settings.
    *   **Key Models/Collections**:
        *   `User` (`User.js`, potentially also `UserModels.js` variants): Manages user profiles, authentication details, settings, push notification tokens (`fcmToken`), preferences, linked accounts, potentially profile view counts.
        *   `Choice` (`choiceModel.js`): Stores the detailed user experiences (ratings, consumed items, emotions, comments) linked to locations/events. Core user-generated content.
        *   `Interaction` (`Interaction.js`): Logs generic user interactions like likes, views on various content types (posts, choices, etc.). Used for analytics and feed algorithms.
        *   `Post` (`Post.js`): Represents user-generated posts, potentially created when a "Choice" is shared (`createPost: true`) or independently. Contains content, media references, likes, comments.
        *   `Follow` (`Follow.js`): Manages the user-to-user and user-to-producer following relationships, forming the social graph.
        *   `Conversation` (`conversation.js`): Represents messaging conversations between users, storing participant information and metadata.
        *   `Message` (`message.js`): Stores individual messages within conversations.
        *   `Call` (`call.js`): Logs video/audio call history and details.
        *   `ProfileView` (`ProfileView.js`): Tracks views of user or producer profiles for analytics.
        *   `Offer` (`Offer.js`): Could potentially store general offers or be primarily used within producer DBs; its location needs verification based on usage in routes.
        *   `Subscription` (`Subscription.js`): Tracks user or producer premium subscription status (likely linked to Stripe).
        *   `SentPush` (`SentPush.js`): Logs push notifications sent to users.
        *   `contactTag` (`contactTag.js`): Likely used for CRM purposes, potentially tagging users/contacts.
        *   `heatmapData` (`heatmapData.js`): Could store pre-aggregated data for generating heatmaps, potentially combining location history and choice data.
        *   **(Conceptual/New)** `Interest`: Collection to store user-expressed desires for future experiences.

2.  **`restaurationDb` (Restaurant Producer Data)**
    *   **Purpose**: Dedicated storage for all information specific to Restaurant Producers.
    *   **Key Models/Collections**:
        *   `Producer` (`Producer.js`): Defines the schema for restaurant producers, including profile information, address, location, contact details, cuisine types, opening hours, photos, owner references, and critically, the detailed menu (`structured_data` - which can be enhanced by AI analysis for calorie/carbon footprint estimates and popularity).
        *   `RestaurantStats` (`RestaurantStats.js`): Potentially stores aggregated statistics specific to restaurants for faster retrieval on dashboards.
        *   `Rating` (`Rating.js`): This might store overall ratings or could be superseded by the detailed ratings within the `Choice` model in `choiceAppDb`. Needs clarification based on route usage.

3.  **`loisirsDb` (Leisure Producer Data)**
    *   **Purpose**: Dedicated storage for Leisure Producers and their associated events.
    *   **Key Models/Collections**:
        *   `LeisureProducer` (`leisureProducer.js`): Defines the schema for leisure producers (activity centers, venues), including profile info, location, activity types, photos, pricing. **Crucially, they can also create and manage their own events directly.**
        *   `Event` (`event.js`): Manages events, including those created by leisure producers directly in-app or ingested from partner platforms. Includes details like title, description, date, time, location, price, category. These are linked to user "Choices."

4.  **`beautyWellnessDb` (Wellness Producer Data)**
    *   **Purpose**: Dedicated storage for Wellness Producers (spas, salons, clinics, etc.).
    *   **Key Models/Collections**:
        *   `WellnessPlace` (`WellnessPlace.js`): Defines the schema for wellness establishments, including profile info, location, service types, photos, schedule, pricing, and the crucial `criteria_ratings` used by users when creating "Choices." (Services and offerings can be enhanced with AI-derived insights).

**(Note:** The exact usage and relationships between some models, like `Rating` vs `Choice.ratings`, or the precise home for `Offer`, would require deeper inspection of the controller and route logic in the backend codebase. The AI-driven data enrichment (calories, carbon footprint) represents a sophisticated feature set to be progressively implemented.)**

This synthesis aims to provide a solid foundation for understanding and evolving the Choice App project, **highlighting its potential as a differentiated social platform (Instagram x Yelp/TripAdvisor hybrid powered by AI-enriched data) and a powerful producer tool.**
Further exploration of the backend source code (controllers, specific Mongoose models) would be necessary to refine the exact MongoDB data structures and detailed business logic for both existing and proposed functionalities like "Interests," advanced real-time producer tools, AI data ingestion pipelines, **and to connect all intended UI elements to functional backend operations.** 