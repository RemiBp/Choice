import 'package:flutter/material.dart';
import 'dart:async';

/// A custom carousel controller that doesn't conflict with Flutter's Material library
class ChoiceCarouselController {
  // Controller is lazily initialized when needed
  PageController? _pageController;
  
  // Use getter to safely access controller (always create if null)
  PageController get pageController {
    _pageController ??= PageController();
    return _pageController!;
  }
  
  // Set new controller instance
  set pageController(PageController controller) {
    _pageController = controller;
  }
  
  /// The current page index
  int _currentPage = 0;
  int get currentPage => _currentPage;
  
  /// Whether the carousel is ready to be controlled
  bool _isReady = false;
  bool get isReady => _isReady;
  
  /// Initialize the controller
  void initialize() {
    _isReady = true;
  }
  
  /// Reset the controller (for safe cleanup)
  void reset() {
    _isReady = false;
    _currentPage = 0;
    // Don't dispose here, just clear reference if needed
  }
  
  /// Jump to a specific page
  void jumpToPage(int page) {
    if (_isReady && _pageController != null) {
      pageController.jumpToPage(page);
      _currentPage = page;
    }
  }
  
  /// Animate to the next page
  void nextPage({Duration duration = const Duration(milliseconds: 300), Curve curve = Curves.ease}) {
    if (_isReady && _pageController != null && 
        _currentPage < pageController.position.viewportDimension) {
      pageController.nextPage(duration: duration, curve: curve);
      _currentPage++;
    }
  }
  
  /// Animate to the previous page
  void previousPage({Duration duration = const Duration(milliseconds: 300), Curve curve = Curves.ease}) {
    if (_isReady && _pageController != null && _currentPage > 0) {
      pageController.previousPage(duration: duration, curve: curve);
      _currentPage--;
    }
  }
  
  /// Animate to a specific page
  void animateToPage(int page, {Duration duration = const Duration(milliseconds: 300), Curve curve = Curves.ease}) {
    if (_isReady && _pageController != null) {
      pageController.animateToPage(page, duration: duration, curve: curve);
      _currentPage = page;
    }
  }
  
  /// Track if controller was externally created
  bool _isExternalController = false;
  
  /// Dispose the controller
  void dispose() {
    // Only dispose the page controller if it wasn't externally created
    if (!_isExternalController && _pageController != null) {
      _pageController!.dispose();
      _pageController = null;
    }
    _isReady = false;
  }
}

/// Options for the ChoiceCarousel
class ChoiceCarouselOptions {
  /// Height of the carousel
  final double? height;
  
  /// Whether to enable infinite scroll
  final bool enableInfiniteScroll;
  
  /// Whether to auto-play the carousel
  final bool autoPlay;
  
  /// Duration between auto-play transitions
  final Duration autoPlayInterval;
  
  /// Duration for auto-play animations
  final Duration autoPlayAnimationDuration;
  
  /// Fraction of the viewport to show
  final double viewportFraction;
  
  /// Whether to enlarge the center page
  final bool enlargeCenterPage;
  
  /// Curve for animations
  final Curve curve;
  
  /// Scroll direction
  final Axis scrollDirection;
  
  /// Constructor with default values
  ChoiceCarouselOptions({
    this.height,
    this.enableInfiniteScroll = false,
    this.autoPlay = false,
    this.autoPlayInterval = const Duration(seconds: 4),
    this.autoPlayAnimationDuration = const Duration(milliseconds: 800),
    this.viewportFraction = 0.8,
    this.enlargeCenterPage = false,
    this.curve = Curves.fastOutSlowIn,
    this.scrollDirection = Axis.horizontal,
  });
}

/// A custom carousel widget that replaces CarouselSlider without import conflicts
class ChoiceCarousel extends StatefulWidget {
  /// Controller for the carousel
  final ChoiceCarouselController? controller;
  
  /// Options for the carousel
  final ChoiceCarouselOptions options;
  
  /// Items to display in the carousel
  final List<Widget> items;
  
  /// Optional builder for the items
  final Widget Function(BuildContext, int, int)? itemBuilder;
  
  /// Number of items if using builder
  final int? itemCount;
  
  /// Callback when page changes
  final void Function(int, CarouselPageChangedReason)? onPageChanged;
  
  /// Constructor for items list
  ChoiceCarousel({
    Key? key,
    required this.items,
    this.controller,
    ChoiceCarouselOptions? options,
    this.onPageChanged,
  })  : itemBuilder = null,
        itemCount = null,
        options = options ?? ChoiceCarouselOptions(),
        super(key: key);
  
  /// Constructor for item builder
  ChoiceCarousel.builder({
    Key? key,
    required this.itemBuilder,
    required this.itemCount,
    this.controller,
    ChoiceCarouselOptions? options,
    this.onPageChanged,
  })  : items = const [],
        options = options ?? ChoiceCarouselOptions(),
        super(key: key);
  
  @override
  State<ChoiceCarousel> createState() => _ChoiceCarouselState();
}

/// Reason for page change
enum CarouselPageChangedReason {
  timed,
  manual,
  controller,
}

class _ChoiceCarouselState extends State<ChoiceCarousel> with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late ChoiceCarouselController _carouselController;
  Timer? _timer;
  int _currentPage = 0;
  
  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      viewportFraction: widget.options.viewportFraction,
      initialPage: 0,
    );
    
    // Use the controller passed in or create a new one
    _carouselController = widget.controller ?? ChoiceCarouselController();
    
    // If controller was provided externally, mark it as such
    if (widget.controller != null) {
      _carouselController._isExternalController = true;
    }
    
    _carouselController.pageController = _pageController;
    _carouselController.initialize();
    
    if (widget.options.autoPlay) {
      _startAutoPlay();
    }
  }
  
  @override
  void dispose() {
    // First, cancel any timers
    if (_timer?.isActive ?? false) {
      _timer?.cancel();
      _timer = null;
    }
    
    // Reset the controller to prevent further access
    _carouselController.reset();
    
    // If controller was created internally, we need to fully dispose it
    if (widget.controller == null) {
      try {
        _carouselController.dispose();
      } catch (e) {
        print('Warning: Error disposing internal carousel controller: $e');
      }
    }
    
    // Always dispose our own PageController reference
    try {
      if (_pageController.hasClients) {
        _pageController.dispose();
      }
    } catch (e) {
      print('Warning: Error disposing page controller: $e');
    }
    
    super.dispose();
  }
  
  void _startAutoPlay() {
    _timer = Timer.periodic(widget.options.autoPlayInterval, (_) {
      if (widget.options.enableInfiniteScroll || 
          _currentPage < (widget.itemCount ?? widget.items.length) - 1) {
        int nextPage = _currentPage + 1;
        if (!widget.options.enableInfiniteScroll && 
            nextPage >= (widget.itemCount ?? widget.items.length)) {
          nextPage = 0;
        }
        _pageController.animateToPage(
          nextPage,
          duration: widget.options.autoPlayAnimationDuration,
          curve: widget.options.curve,
        );
      } else {
        // If we're at the end and not infinite scrolling, go back to start
        _pageController.animateToPage(
          0,
          duration: widget.options.autoPlayAnimationDuration,
          curve: widget.options.curve,
        );
      }
    });
  }
  
  void _stopAutoPlay() {
    _timer?.cancel();
    _timer = null;
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.options.height,
      child: PageView.builder(
        controller: _pageController,
        scrollDirection: widget.options.scrollDirection,
        onPageChanged: (index) {
          setState(() {
            _currentPage = index;
            _carouselController._currentPage = index;
          });
          if (widget.onPageChanged != null) {
            widget.onPageChanged!(index, CarouselPageChangedReason.manual);
          }
        },
        itemCount: widget.itemBuilder != null ? widget.itemCount : widget.items.length,
        itemBuilder: (context, index) {
          final effectiveIndex = widget.options.enableInfiniteScroll
              ? index % (widget.itemBuilder != null ? widget.itemCount! : widget.items.length)
              : index;
          
          Widget child;
          if (widget.itemBuilder != null) {
            child = widget.itemBuilder!(context, effectiveIndex, index);
          } else {
            child = widget.items[effectiveIndex];
          }
          
          if (widget.options.enlargeCenterPage) {
            // Apply scaling to center page
            child = Transform.scale(
              scale: _currentPage == index ? 1.1 : 1.0,
              child: child,
            );
          }
          
          return child;
        },
      ),
    );
  }
}
