# Choice App Feed Enhancements

## Overview

This update implements several key enhancements to the Choice app's feed functionality:

1. **Dialogic AI Feed Integration** - AI-driven messages now appear within the feed, providing personalized recommendations
2. **Enhanced Backend Connectivity** - Robust handling of various post data structures from the backend
3. **Improved Feed UI** - Enhanced styling and interaction buttons for all post types
4. **Full-screen Reels** - Support for swipeable full-screen videos with proper controls
5. **Bug Fixes** - Resolved import conflicts and type errors

## Key Components

### Media Model

A `Media` model was added to properly handle media attachments in posts:

```dart
class Media {
  final String url;
  final String type;
  final double width;
  final double height;
  
  // ...
}
```

### FeedScreenController

The `FeedScreenController` has been enhanced with:

- Dynamic post handling - supports both `Post` objects and raw `Map<String, dynamic>` structures
- AI integration - works with `DialogicAIFeedService` to fetch contextual AI messages
- Type conversion - automatically converts dynamic data to strongly-typed models when needed

```dart
// Example: Converting dynamic posts to Post objects
List<Post> _convertToPostList(List<dynamic> items) {
  List<Post> result = [];
  
  for (var item in items) {
    if (item is Post) {
      // Already a Post, just add it
      result.add(item);
    } else if (item is Map<String, dynamic>) {
      // Convert Map to Post
      // ...
    }
  }
  
  return result;
}
```

### DialogicAIFeedService

This new service provides AI-driven messaging capabilities for the feed:

- `getContextualMessage()` - Generates personalized messages based on user behavior
- `getResponseToUserInteraction()` - Handles user responses to AI messages
- `getEmotionalRecommendations()` - Maps user emotions to content recommendations

## Carousel Utility

To resolve import conflicts with `CarouselController` being imported from both `carousel_slider` and Flutter's material library, we've added a wrapper class:

```dart
// Use this class instead of directly importing CarouselController
class ChoiceCarouselController extends carousel_package.CarouselController {
  ChoiceCarouselController();
  
  static ChoiceCarouselController create() {
    return ChoiceCarouselController();
  }
}
```

### Usage

```dart
import 'package:carousel_slider/carousel_slider.dart';
import '../utils/carousel_util.dart';

// In your widget:
final carouselController = ChoiceCarouselController.create();

// Then use it with CarouselSlider:
CarouselSlider(
  carouselController: carouselController,
  items: [...],
  options: CarouselOptions(...),
);
```

## Future Improvements

Future enhancements could include:

1. Further optimizing the AI dialogic messages based on user feedback
2. Enhancing media handling with full-screen gallery view
3. Adding feed personalization based on user behavior and preferences
4. Implementing a shared element transition when opening posts