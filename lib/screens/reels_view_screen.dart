import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';
import '../utils.dart' show getImageProvider;

class ReelsViewScreen extends StatefulWidget {
  final int initialIndex;
  final List<Map<String, dynamic>> videos;
  final Function(int, Map<String, dynamic>)? onLike;
  final Function(int, Map<String, dynamic>)? onInterest;
  final Function(Map<String, dynamic>)? onProfileTap;

  const ReelsViewScreen({
    Key? key,
    required this.initialIndex,
    required this.videos,
    this.onLike,
    this.onInterest,
    this.onProfileTap,
  }) : super(key: key);

  @override
  State<ReelsViewScreen> createState() => _ReelsViewScreenState();
}

class _ReelsViewScreenState extends State<ReelsViewScreen> {
  late PageController _pageController;
  int _currentIndex = 0;
  final Map<int, VideoPlayerController?> _controllers = {};
  final Map<int, bool> _isInitialized = {};
  bool _showControls = true;
  bool _isMuted = false;
  final Map<String, dynamic> _localInteractionState = {};
  
  @override
  void initState() {
    super.initState();
    
    // Forcer le mode plein écran et portrait
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    
    _currentIndex = widget.initialIndex >= 0 ? widget.initialIndex : 0;
    _pageController = PageController(initialPage: _currentIndex);
    
    // Initialiser le contrôleur pour la vidéo initiale
    _initializeController(_currentIndex);
    
    // Préparer également les vidéos adjacentes
    if (_currentIndex > 0) {
      _initializeController(_currentIndex - 1);
    }
    if (_currentIndex < widget.videos.length - 1) {
      _initializeController(_currentIndex + 1);
    }
    
    // Masquer les contrôles après quelques secondes
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }
  
  Future<void> _initializeController(int index) async {
    if (index < 0 || index >= widget.videos.length) return;
    if (_controllers[index] != null) return;
    
    try {
      final videoUrl = widget.videos[index]['url'];
      print('🎬 Initialisation de la vidéo à l\'index $index: $videoUrl');
      
      final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      _controllers[index] = controller;
      _isInitialized[index] = false;
      
      await controller.initialize();
      controller.setLooping(true);
      
      // Démarrer la lecture si c'est la vidéo actuelle
      if (index == _currentIndex) {
        controller.play();
        controller.setVolume(_isMuted ? 0.0 : 1.0);
      }
      
      if (mounted) {
        setState(() {
          _isInitialized[index] = true;
        });
      }
    } catch (e) {
      print('❌ Erreur lors de l\'initialisation de la vidéo: $e');
      _controllers[index] = null;
    }
  }
  
  void _disposeController(int index) {
    final controller = _controllers[index];
    if (controller != null) {
      controller.dispose();
      _controllers[index] = null;
      _isInitialized[index] = false;
    }
  }
  
  void _onPageChanged(int index) {
    if (!mounted) return;
    
    // Arrêter la vidéo précédente
    if (_controllers[_currentIndex] != null) {
      _controllers[_currentIndex]!.pause();
    }
    
    // Mettre à jour l'index courant
    setState(() {
      _currentIndex = index;
    });
    
    // Démarrer la vidéo courante
    if (_controllers[index] != null && _isInitialized[index] == true) {
      _controllers[index]!.play();
      _controllers[index]!.setVolume(_isMuted ? 0.0 : 1.0);
    } else {
      _initializeController(index);
    }
    
    // Précharger la vidéo suivante
    if (index < widget.videos.length - 1) {
      _initializeController(index + 1);
    }
    
    // Précharger la vidéo précédente
    if (index > 0) {
      _initializeController(index - 1);
    }
    
    // Libérer les contrôleurs trop éloignés pour économiser de la mémoire
    for (int i = 0; i < widget.videos.length; i++) {
      if (i < index - 1 || i > index + 1) {
        _disposeController(i);
      }
    }
    
    // Rendre les contrôles visibles brièvement
    setState(() {
      _showControls = true;
    });
    
    // Masquer les contrôles après quelques secondes
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }
  
  void _togglePlayPause() {
    final controller = _controllers[_currentIndex];
    if (controller != null && _isInitialized[_currentIndex] == true) {
      setState(() {
        if (controller.value.isPlaying) {
          controller.pause();
        } else {
          controller.play();
        }
      });
    }
  }
  
  void _toggleMute() {
    final controller = _controllers[_currentIndex];
    if (controller != null && _isInitialized[_currentIndex] == true) {
      setState(() {
        _isMuted = !_isMuted;
        controller.setVolume(_isMuted ? 0.0 : 1.0);
      });
    }
  }
  
  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  @override
  void dispose() {
    // Restaurer l'interface système
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    // Libérer tous les contrôleurs
    for (var controller in _controllers.values) {
      if (controller != null) {
        controller.dispose();
      }
    }
    _controllers.clear();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Contenu principal
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: widget.videos.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: _toggleControls,
                child: _buildVideoItem(context, index, widget.videos[index]),
              );
            },
          ),
          
          // Contrôles vidéo
          if (_showControls)
            Positioned(
              top: 16,
              left: 16,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
              
          // Indicateur de lecture/pause
          if (_showControls)
            Positioned.fill(
              child: Center(
                child: IconButton(
                  icon: Icon(
                    _controllers[_currentIndex]?.value.isPlaying ?? false
                        ? Icons.pause_circle_outline
                        : Icons.play_circle_outline,
                    color: Colors.white,
                    size: 80,
                  ),
                  onPressed: _togglePlayPause,
                ),
              ),
            ),
            
          // Contrôle du son
          if (_showControls)
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                icon: Icon(
                  _isMuted ? Icons.volume_off : Icons.volume_up,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: _toggleMute,
              ),
            ),
            
          // Indicateur de progression
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Row(
              children: List.generate(
                widget.videos.length,
                (index) => Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
                    height: 3,
                    decoration: BoxDecoration(
                      color: index == _currentIndex
                          ? Colors.white
                          : Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // Informations sur la vidéo
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _buildVideoInfo(widget.videos[_currentIndex]),
          ),
        ],
      ),
    );
  }
  
  Widget _buildVideoItem(BuildContext context, int index, Map<String, dynamic> video) {
    final String videoUrl = video['url'] ?? '';
    final String type = video['type'] ?? 'video';
    final String thumbnailUrl = video['thumbnailUrl'] ?? '';
    
    // Determine post data for interaction
    final dynamic post = video['post'] ?? {};
    final int postId = post is Map ? (post['id'] ?? 0) : 0;
    final bool isLiked = post is Map ? (post['isLiked'] ?? false) : false;
    final bool isInterested = post is Map ? (post['isInterested'] ?? false) : false;
    final int likesCount = post is Map ? (post['likesCount'] ?? 0) : 0;
    final int interestedCount = post is Map ? (post['interestedCount'] ?? 0) : 0;

    // Create local state for like/interest to provide immediate feedback
    if (!_localInteractionState.containsKey('post_$postId')) {
      _localInteractionState['post_$postId'] = {
        'isLiked': isLiked,
        'isInterested': isInterested,
        'likesCount': likesCount,
        'interestedCount': interestedCount,
      };
    }

    final localState = _localInteractionState['post_$postId']!;
    
    return Stack(
      children: [
        // Video content
        Center(
          child: type == 'video'
              ? _controllers.containsKey(index) && _controllers[index]!.value.isInitialized
                  ? AspectRatio(
                      aspectRatio: _controllers[index]!.value.aspectRatio,
                      child: VideoPlayer(_controllers[index]!),
                    )
                  : Container(
                      color: Colors.black,
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                        ),
                      ),
                    )
              : (() {
                final imageProvider = getImageProvider(thumbnailUrl);
                if (imageProvider != null) {
                  return Image(
                    image: imageProvider,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.black,
                      child: const Center(child: Icon(Icons.broken_image, color: Colors.white70)),
                    ),
                  );
                } else {
                  return Container(
                    color: Colors.black,
                    child: const Center(child: Icon(Icons.broken_image, color: Colors.white70)),
                  );
                }
              })(),
        ),
        
        // Info overlay (Author info, description, etc.)
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _buildVideoInfo(video),
        ),
        
        // Interaction buttons on the right side
        Positioned(
          right: 16,
          bottom: MediaQuery.of(context).size.height * 0.15,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Like button
              _buildInteractionButton(
                icon: localState['isLiked'] ? Icons.favorite : Icons.favorite_border,
                label: formatCount(localState['likesCount']),
                iconColor: localState['isLiked'] ? Colors.red : Colors.white,
                onTap: () {
                  setState(() {
                    final bool newLikedState = !localState['isLiked'];
                    _localInteractionState['post_$postId']!['isLiked'] = newLikedState;
                    _localInteractionState['post_$postId']!['likesCount'] = newLikedState 
                        ? localState['likesCount'] + 1 
                        : localState['likesCount'] - 1;
                  });
                  
                  // Call the callback
                  if (widget.onLike != null && post is Map) {
                    widget.onLike!(postId, Map<String, dynamic>.from(post));
                  }
                },
              ),
              
              const SizedBox(height: 20),
              
              // Interest button
              _buildInteractionButton(
                icon: localState['isInterested'] ? Icons.star : Icons.star_border,
                label: formatCount(localState['interestedCount']),
                iconColor: localState['isInterested'] ? Colors.amber : Colors.white,
                onTap: () {
                  setState(() {
                    final bool newInterestedState = !localState['isInterested'];
                    _localInteractionState['post_$postId']!['isInterested'] = newInterestedState;
                    _localInteractionState['post_$postId']!['interestedCount'] = newInterestedState 
                        ? localState['interestedCount'] + 1 
                        : localState['interestedCount'] - 1;
                  });
                  
                  // Call the callback
                  if (widget.onInterest != null && post is Map) {
                    widget.onInterest!(postId, Map<String, dynamic>.from(post));
                  }
                },
              ),
              
              const SizedBox(height: 20),
              
              // Comment button
              _buildInteractionButton(
                icon: Icons.chat_bubble_outline,
                label: '',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Fonctionnalité commentaires en développement'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 20),
              
              // Share button
              _buildInteractionButton(
                icon: Icons.share_outlined,
                label: '',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Fonctionnalité partage en développement'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 20),
              
              // Save button
              _buildInteractionButton(
                icon: Icons.bookmark_border,
                label: '',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Fonctionnalité sauvegarde en développement'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        
        // Tap area for pausing/playing video
        Positioned.fill(
          child: GestureDetector(
            onTap: () {
              if (type == 'video' && _controllers.containsKey(index)) {
                setState(() {
                  if (_controllers[index]!.value.isPlaying) {
                    _controllers[index]!.pause();
                  } else {
                    _controllers[index]!.play();
                  }
                });
              }
            },
          ),
        ),
      ],
    );
  }
  
  // Helper method to build interaction buttons
  Widget _buildInteractionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color iconColor = Colors.white,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
      children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withOpacity(0.3),
            ),
            padding: const EdgeInsets.all(8),
            child: Icon(
              icon,
              color: iconColor,
              size: 26,
            ),
          ),
          if (label.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
          ),
        ),
      ],
      ),
    );
  }
  
  // Helper method to format counts (1000 -> 1K)
  String formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    } else {
      return count.toString();
    }
  }
  
  Widget _buildVideoInfo(Map<String, dynamic> videoData) {
    // Extract post data
    final post = videoData['post'] ?? {};
    
    // Extract author information
    final String authorName = post is Map ? (post['authorName'] ?? 'Utilisateur') : 'Utilisateur';
    final String authorAvatar = post is Map ? (post['authorAvatar'] ?? '') : '';
    
    // Extract or build description
    String description = '';
    if (post is Map) {
      description = post['description'] ?? post['content'] ?? '';
      if (description.isEmpty) {
        // Generate a random description if none is available
        final List<String> randomDescriptions = [
          "Un moment spécial à partager avec vous tous !",
          "Découverte du jour - qu'en pensez-vous ?",
          "Une expérience unique que je recommande vivement !",
          "Le meilleur endroit que j'ai visité récemment !",
          "À ne pas manquer si vous êtes dans le coin !",
        ];
        description = randomDescriptions[DateTime.now().millisecond % randomDescriptions.length];
      }
    }
    
    // Track if description is expanded
    final descriptionKey = 'desc_${post is Map ? (post['id'] ?? DateTime.now().toString()) : DateTime.now().toString()}';
    if (!_localInteractionState.containsKey(descriptionKey)) {
      _localInteractionState[descriptionKey] = {'isExpanded': false};
    }
    final bool isDescriptionExpanded = _localInteractionState[descriptionKey]!['isExpanded'];
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withOpacity(0.7),
            Colors.black,
          ],
        ),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author info
          Row(
            children: [
              // Author avatar with profile tap
              GestureDetector(
                onTap: widget.onProfileTap != null ? () => widget.onProfileTap!(post) : null,
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: getImageProvider(authorAvatar) ?? const AssetImage('assets/images/default_avatar.png'),
                  child: getImageProvider(authorAvatar) == null ? Icon(Icons.person, color: Colors.grey[400]) : null,
                ),
              ),
              const SizedBox(width: 12),
              
              // Author name and location
              Expanded(
                child: GestureDetector(
                  onTap: widget.onProfileTap != null ? () => widget.onProfileTap!(post) : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      authorName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                      if (post is Map && post['locationName'] != null && post['locationName'].toString().isNotEmpty)
                    Row(
                      children: [
                            const Icon(
                              Icons.location_on,
                              color: Colors.white70,
                              size: 14,
                          ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                post['locationName'],
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  ),
                ),
              ),
              
              // Follow button
              OutlinedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Fonctionnalité "suivre" en développement'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: const Text(
                  'Suivre',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Description with expandable text
          if (description.isNotEmpty)
            GestureDetector(
              onTap: () {
                setState(() {
                  _localInteractionState[descriptionKey]!['isExpanded'] = !isDescriptionExpanded;
                });
              },
              child: Text(
              description,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
                maxLines: isDescriptionExpanded ? null : 2,
                overflow: isDescriptionExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
              ),
            ),
            
          const SizedBox(height: 12),
          
          // Tags
          if (post is Map && post['tags'] != null && post['tags'] is List && post['tags'].isNotEmpty)
            Wrap(
              spacing: 8,
              children: List.generate(
                post['tags'].length,
                (index) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '#${post['tags'][index]}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
                    ),
                  ),
                ),
            ),
          ),
      ],
      ),
    );
  }
}