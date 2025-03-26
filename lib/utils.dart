// Utility functions for the app

/// Returns the base URL for API requests
String getBaseUrl() {
  // You might want to change this based on your environment
  const bool isProduction = false;
  
  if (isProduction) {
    return 'https://api.choice-app.com';
  } else {
    // Development URL - using 10.0.2.2 for Android emulator
    return 'http://10.0.2.2:5000';
  }
}