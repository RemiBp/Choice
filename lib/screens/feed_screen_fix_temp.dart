// Cette fonction convertit toute réponse (liste ou map) en liste itérable
// Cela résout le problème de 'for (var item in response)' quand response est une Map
List<dynamic> _safeIterateResponse(dynamic response) {
  if (response == null) {
    return [];
  }
  
  if (response is List) {
    // Si c'est déjà une liste, retourner directement
    return response;
  } else if (response is Map<String, dynamic>) {
    // Si c'est une Map qui contient une clé 'posts' qui est une liste
    if (response.containsKey('posts') && response['posts'] is List) {
      return response['posts'] as List;
    } else {
      // Sinon, retourner un singleton contenant la Map
      return [response];
    }
  } else {
    // Pour tout autre type, retourner une liste vide
    print('❌ Type de réponse non pris en charge pour itération: ${response.runtimeType}');
    return [];
  }
}

// INSTRUCTIONS POUR CORRIGER L'ERREUR:
// 
// 1. Copie la fonction _safeIterateResponse ci-dessus dans ton fichier feed_screen_controller.dart
// 
// 2. Recherche et remplace chaque occurrence de:
//    for (var item in response) {
//    
//    par:
//    for (var item in _safeIterateResponse(response)) {
//
// Cela garantira que tu n'auras plus jamais d'erreur "Map<String, dynamic> used in the 'for' loop" 