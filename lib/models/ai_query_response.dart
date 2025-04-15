import 'profile_data.dart'; // Assuming ProfileData model exists

// Represents the structured response from the AI producer query endpoint.
class AiQueryResponse {
  final String response; // The natural language response from the AI
  final List<ProfileData>? profiles; // Optional list of relevant profiles (e.g., competitors) - Make nullable

  AiQueryResponse({
    required this.response, // Use required keyword
    this.profiles, // Nullable, so no required needed
  });

  factory AiQueryResponse.fromJson(Map<String, dynamic> json) {
    var profilesList = json['profiles'] as List?;
    List<ProfileData>? profilesData = profilesList
        ?.map((i) => ProfileData.fromJson(i))
        .toList(); // Allow profilesData to be null

    return AiQueryResponse(
      response: json['response'] as String ?? 'Désolé, je n\'ai pas pu répondre.',
      profiles: profilesData,
    );
  }

  Map<String, dynamic> toJson() => {
        'response': response,
        'profiles': profiles?.map((p) => p.toJson())?.toList(),
      };
} 