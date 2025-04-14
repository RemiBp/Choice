import '../../widgets/profile/badges_summary_widget.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // ... existing appBar ...
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ... existing widgets ...
            
            // Ajouter le widget de résumé des badges
            const BadgesSummaryWidget(),
            
            // ... rest of the existing widgets ...
          ],
        ),
      ),
    );
  }
  
  // ... existing methods ...
} 