// This file provides a wrapper around carousel_slider's CarouselController
// to avoid naming conflicts with Flutter's material library CarouselController

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_controller.dart' as carousel_package;

/// A wrapper around carousel_slider's CarouselController to avoid naming conflicts
///
/// Use this class instead of directly importing CarouselController from carousel_slider
/// This ensures that there's no conflict with Flutter's material library
class ChoiceCarouselController implements carousel_package.CarouselController {
  // Internal implementation of the controller
  final carousel_package.CarouselControllerImpl _impl = carousel_package.CarouselControllerImpl();
  
  /// Creates a new carousel controller wrapper
  ChoiceCarouselController();
  
  /// Create a new CarouselController instance
  static ChoiceCarouselController create() {
    return ChoiceCarouselController();
  }
  
  /// Get the ready state of the controller
  @override
  bool get ready => _impl.ready;
  
  /// Get a future that completes when the controller is ready
  @override
  Future<Null> get onReady => _impl.onReady;
  
  /// Jump to a specific page without animation
  @override
  void jumpToPage(int page) => _impl.jumpToPage(page);
  
  /// Animate to the next page
  @override
  Future<void> nextPage({Duration? duration, Curve? curve}) => 
      _impl.nextPage(duration: duration, curve: curve);
  
  /// Animate to the previous page
  @override
  Future<void> previousPage({Duration? duration, Curve? curve}) => 
      _impl.previousPage(duration: duration, curve: curve);
  
  /// Animate to a specific page
  @override
  Future<void> animateToPage(int page, {Duration? duration, Curve? curve}) => 
      _impl.animateToPage(page, duration: duration, curve: curve);
  
  /// Start auto-play of the carousel
  @override
  void startAutoPlay() => _impl.startAutoPlay();
  
  /// Stop auto-play of the carousel
  @override
  void stopAutoPlay() => _impl.stopAutoPlay();
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