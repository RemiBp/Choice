#!/bin/bash

# Script to fix iOS CocoaPods issues
echo "Starting iOS CocoaPods fix script..."

# Clean Flutter build cache
echo "Cleaning Flutter build cache..."
flutter clean

# Get dependencies
echo "Getting Flutter dependencies..."
flutter pub get

# Clear CocoaPods cache
echo "Clearing CocoaPods cache..."
cd ios
rm -rf Pods
rm -f Podfile.lock

# Update CocoaPods repo
echo "Updating CocoaPods repositories..."
pod repo update

# Force pod install
echo "Running pod install with force option..."
pod install --verbose --repo-update

# Go back to main directory
cd ..

echo "All done! Your iOS build should now be ready." 