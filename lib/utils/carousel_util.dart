// This file provides a wrapper around carousel_slider's CarouselController
// to avoid naming conflicts with Flutter's material library CarouselController

// We use a specific import to avoid the conflict
import 'package:carousel_slider/carousel_controller.dart' as carousel_package;

/// A wrapper around carousel_slider's CarouselController to avoid naming conflicts
/// 
/// Use this class instead of directly importing CarouselController from carousel_slider
/// This ensures that there's no conflict with Flutter's material library
class ChoiceCarouselController extends carousel_package.CarouselController {
  ChoiceCarouselController();
  
  /// Create a new CarouselController instance
  static ChoiceCarouselController create() {
    return ChoiceCarouselController();
  }
}

/// When you need to use CarouselSlider, import this file and use this pattern:
/// 
/// ```dart
/// import 'package:carousel_slider/carousel_slider.dart';
/// import '../utils/carousel_util.dart';
/// 
/// // In your widget:
/// final carouselController = ChoiceCarouselController.create();
/// 
/// // Then use it with CarouselSlider:
/// CarouselSlider(
///   carouselController: carouselController,
///   items: [...],
///   options: CarouselOptions(...),
/// );