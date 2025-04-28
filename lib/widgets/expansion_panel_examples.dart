import 'package:flutter/material.dart';
import 'expansion_panel.dart';

class ExpansionPanelExamples extends StatelessWidget {
  const ExpansionPanelExamples({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Expansion Panel Examples'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Basic Expansion Panel',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8.0),
            _buildBasicPanel(),
            
            SizedBox(height: 24.0),
            Text(
              'Styled Expansion Panel',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8.0),
            _buildStyledPanel(context),
            
            SizedBox(height: 24.0),
            Text(
              'Custom Icons Expansion Panel',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8.0),
            _buildCustomIconsPanel(),
            
            SizedBox(height: 24.0),
            Text(
              'Expansion Panel List',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8.0),
            _buildExpansionPanelList(),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicPanel() {
    return CustomExpansionPanel(
      title: 'What is Flutter?',
      content: Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Text(
          'Flutter is Google\'s UI toolkit for building beautiful, natively compiled applications for mobile, web, and desktop from a single codebase.',
          style: TextStyle(fontSize: 14.0),
        ),
      ),
    );
  }

  Widget _buildStyledPanel(BuildContext context) {
    return CustomExpansionPanel(
      title: 'Subscription Benefits',
      headerColor: Theme.of(context).primaryColor,
      contentBackgroundColor: Colors.grey[50],
      headerTextStyle: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 16.0,
      ),
      borderRadius: 12.0,
      initiallyExpanded: true,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBenefitItem('Access to premium content'),
          _buildBenefitItem('Priority customer support'),
          _buildBenefitItem('Ad-free experience'),
          _buildBenefitItem('Exclusive features'),
        ],
      ),
    );
  }

  Widget _buildBenefitItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 20.0),
          SizedBox(width: 8.0),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14.0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomIconsPanel() {
    return CustomExpansionPanel(
      title: 'Frequently Asked Questions',
      icon: Icon(Icons.add, size: 24.0),
      expandedIcon: Icon(Icons.remove, size: 24.0),
      content: Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Q: How do I reset my password?'),
            SizedBox(height: 8.0),
            Text('A: You can reset your password by clicking on the "Forgot Password" link on the login page.'),
            SizedBox(height: 16.0),
            Text('Q: How do I contact support?'),
            SizedBox(height: 8.0),
            Text('A: You can contact our support team through the Help Center or by emailing support@example.com.'),
          ],
        ),
      ),
    );
  }

  Widget _buildExpansionPanelList() {
    return CustomExpansionPanelList(
      children: [
        CustomExpansionPanel(
          title: 'Starter Plan',
          content: Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text('Perfect for beginners. Includes basic features.'),
          ),
        ),
        CustomExpansionPanel(
          title: 'Pro Plan',
          content: Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text('Ideal for professionals. Includes advanced features and priority support.'),
          ),
        ),
        CustomExpansionPanel(
          title: 'Enterprise Plan',
          content: Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text('For large organizations. Includes all features, dedicated support, and custom solutions.'),
          ),
        ),
      ],
    );
  }
} 