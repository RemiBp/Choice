import 'package:flutter/material.dart';
import '../components/custom_expansion_panel.dart';

class ExpansionPanelExamples extends StatelessWidget {
  const ExpansionPanelExamples({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expansion Panel Examples'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Basic Example',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            CustomExpansionPanel(
              title: const Text('Tap to expand'),
              content: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'This is the content of the panel that shows when expanded. '
                  'You can put any widget here.',
                ),
              ),
            ),

            const SizedBox(height: 24),
            const Text(
              'Initially Expanded',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            CustomExpansionPanel(
              initiallyExpanded: true,
              title: const Text('This panel starts expanded'),
              content: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'This panel is initially shown in its expanded state.',
                ),
              ),
            ),

            const SizedBox(height: 24),
            const Text(
              'Custom Styling',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            CustomExpansionPanel(
              backgroundColor: Colors.grey.shade100,
              expandedBackgroundColor: Colors.grey.shade200,
              headerBackgroundColor: Colors.blue.shade100,
              headerTextStyle: const TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.bold, 
                fontSize: 16,
              ),
              title: const Text('Custom Styled Panel'),
              content: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('This panel has custom colors and styling.'),
                  SizedBox(height: 10),
                  Text('You can customize many aspects of the appearance.'),
                ],
              ),
            ),

            const SizedBox(height: 24),
            const Text(
              'Custom Icons',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            CustomExpansionPanel(
              collapsedIcon: const Icon(Icons.add_circle, color: Colors.green),
              expandedIcon: const Icon(Icons.remove_circle, color: Colors.red),
              title: const Text('Panel with custom icons'),
              content: const Text('This panel uses custom expand/collapse icons.'),
            ),

            const SizedBox(height: 24),
            const Text(
              'With Complex Content',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            CustomExpansionPanel(
              title: const Text('Panel with complex content'),
              content: Column(
                children: [
                  const Text('This panel contains more complex widgets:'),
                  const SizedBox(height: 12),
                  Container(
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: const Text('A container widget'),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {},
                    child: const Text('A Button'),
                  ),
                  const SizedBox(height: 12),
                  const TextField(
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Input field',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            const Text(
              'Custom Decoration',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            CustomExpansionPanel(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade200, Colors.purple.shade200],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              title: const Text('Panel with gradient decoration'),
              content: const Text(
                'This panel uses a gradient background and custom shadow.',
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
} 