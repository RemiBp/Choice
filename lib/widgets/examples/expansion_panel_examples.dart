import 'package:flutter/material.dart';
import '../custom_expansion_panel.dart';

class ExpansionPanelExamples extends StatefulWidget {
  const ExpansionPanelExamples({Key? key}) : super(key: key);

  @override
  State<ExpansionPanelExamples> createState() => _ExpansionPanelExamplesState();
}

class _ExpansionPanelExamplesState extends State<ExpansionPanelExamples> {
  bool _basicPanelExpanded = false;
  bool _styledPanelExpanded = false;
  bool _customIconPanelExpanded = false;
  
  // For CustomExpansionPanelList example
  List<bool> _multiPanelExpandedStates = [false, false, false];
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('CustomExpansionPanel Examples'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Example section title
            _buildSectionTitle('Basic Usage'),
            const SizedBox(height: 8),
            
            // Basic example
            CustomExpansionPanel(
              title: 'Basic Expansion Panel',
              content: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'This is a basic expansion panel with default styling. '
                  'Tap the header to expand or collapse this panel.',
                ),
              ),
              initiallyExpanded: _basicPanelExpanded,
              onExpansionChanged: (value) {
                setState(() {
                  _basicPanelExpanded = value;
                });
              },
            ),
            
            const SizedBox(height: 24),
            _buildSectionTitle('Styled Panel'),
            const SizedBox(height: 8),
            
            // Styled example
            CustomExpansionPanel(
              title: 'Styled Expansion Panel',
              headerColor: Colors.blue.shade100,
              contentBackgroundColor: Colors.blue.shade50,
              headerTextStyle: TextStyle(
                color: Colors.blue.shade800,
                fontWeight: FontWeight.bold,
              ),
              borderRadius: 8.0,
              content: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'This panel has custom styling with blue colors, '
                  'custom text style, and increased border radius.',
                ),
              ),
              initiallyExpanded: _styledPanelExpanded,
              onExpansionChanged: (value) {
                setState(() {
                  _styledPanelExpanded = value;
                });
              },
            ),
            
            const SizedBox(height: 24),
            _buildSectionTitle('Custom Icons'),
            const SizedBox(height: 8),
            
            // Custom icon example
            CustomExpansionPanel(
              title: 'Panel with Custom Icons',
              content: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'This expansion panel uses custom icons for the '
                  'collapsed and expanded states.',
                ),
              ),
              icon: const Icon(Icons.add_circle_outline),
              expandedIcon: const Icon(Icons.remove_circle_outline),
              initiallyExpanded: _customIconPanelExpanded,
              onExpansionChanged: (value) {
                setState(() {
                  _customIconPanelExpanded = value;
                });
              },
            ),
            
            const SizedBox(height: 24),
            _buildSectionTitle('Multiple Panels with CustomExpansionPanelList'),
            const SizedBox(height: 8),
            
            // CustomExpansionPanelList example
            CustomExpansionPanelList(
              children: [
                CustomExpansionPanel(
                  title: 'Panel 1: Getting Started',
                  content: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text('This is the content for the first panel.'),
                  ),
                  initiallyExpanded: _multiPanelExpandedStates[0],
                  onExpansionChanged: (value) {
                    setState(() {
                      _multiPanelExpandedStates[0] = value;
                    });
                  },
                ),
                CustomExpansionPanel(
                  title: 'Panel 2: Configuration',
                  content: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text('This is the content for the second panel.'),
                  ),
                  initiallyExpanded: _multiPanelExpandedStates[1],
                  onExpansionChanged: (value) {
                    setState(() {
                      _multiPanelExpandedStates[1] = value;
                    });
                  },
                ),
                CustomExpansionPanel(
                  title: 'Panel 3: Advanced Options',
                  content: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text('This is the content for the third panel.'),
                  ),
                  initiallyExpanded: _multiPanelExpandedStates[2],
                  onExpansionChanged: (value) {
                    setState(() {
                      _multiPanelExpandedStates[2] = value;
                    });
                  },
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            _buildSectionTitle('Rich Content Example'),
            const SizedBox(height: 8),
            
            // Rich content example
            CustomExpansionPanel(
              title: 'Panel with Rich Content',
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    'Form Elements',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Name',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {},
                          child: const Text('Submit'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }
} 