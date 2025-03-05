import 'package:flutter/foundation.dart';
import '../models/post.dart';
import '../services/api_service.dart';

class FeedScreenController extends ChangeNotifier {
  final ApiService _apiService;
  List<Post> _posts = [];
  bool _isLoading = false;

  FeedScreenController(this._apiService);

  List<Post> get posts => _posts;
  bool get isLoading => _isLoading;

  Future<void> loadPosts() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.getPosts();
      _posts = response;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      debugPrint('Erreur: $e');
      notifyListeners();
    }
  }
}