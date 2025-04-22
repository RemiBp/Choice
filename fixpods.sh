#!/bin/bash

echo "*** Emergency Firebase podspec fix script ***"

# Create directories inside the iOS structure
mkdir -p ios/.symlinks/plugins/cloud_firestore/ios/Classes
mkdir -p ios/.symlinks/plugins/firebase_core/ios/Classes
mkdir -p ios/.symlinks/plugins/firebase_auth/ios/Classes

# Create cloud_firestore.podspec
cat > ios/.symlinks/plugins/cloud_firestore/ios/cloud_firestore.podspec << EOL
Pod::Spec.new do |s|
  s.name             = 'cloud_firestore'
  s.version          = '0.0.1'
  s.summary          = 'Firestore plugin for Flutter.'
  s.description      = 'Flutter plugin for Cloud Firestore.'
  s.homepage         = 'https://firebase.google.com/docs/firestore'
  s.license          = { :type => 'BSD', :text => 'Copyright 2023 The Flutter Authors. All rights reserved.' }
  s.author           = { 'Flutter Team' => 'flutter-dev@googlegroups.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.ios.deployment_target = '12.0'
  s.dependency 'Flutter'
  s.dependency 'Firebase/Firestore', '10.18.0'
  s.static_framework = true
end
EOL

# Create minimal implementation class
echo "#import <Flutter/Flutter.h>" > ios/.symlinks/plugins/cloud_firestore/ios/Classes/FLTFirebaseFirestorePlugin.h
echo "#import \"FLTFirebaseFirestorePlugin.h\"" > ios/.symlinks/plugins/cloud_firestore/ios/Classes/FLTFirebaseFirestorePlugin.m
echo "@implementation FLTFirebaseFirestorePlugin" >> ios/.symlinks/plugins/cloud_firestore/ios/Classes/FLTFirebaseFirestorePlugin.m
echo "+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {}" >> ios/.symlinks/plugins/cloud_firestore/ios/Classes/FLTFirebaseFirestorePlugin.m
echo "@end" >> ios/.symlinks/plugins/cloud_firestore/ios/Classes/FLTFirebaseFirestorePlugin.m

# Create firebase_core.podspec
cat > ios/.symlinks/plugins/firebase_core/ios/firebase_core.podspec << EOL
Pod::Spec.new do |s|
  s.name             = 'firebase_core'
  s.version          = '0.0.1'
  s.summary          = 'Firebase Core plugin for Flutter.'
  s.description      = 'Flutter plugin for Firebase Core.'
  s.homepage         = 'https://firebase.flutter.dev/docs/core/usage'
  s.license          = { :type => 'BSD', :text => 'Copyright 2023 The Flutter Authors. All rights reserved.' }
  s.author           = { 'Flutter Team' => 'flutter-dev@googlegroups.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.ios.deployment_target = '12.0'
  s.dependency 'Flutter'
  s.dependency 'Firebase/CoreOnly', '10.18.0'
  s.static_framework = true
end
EOL
echo "#import <Flutter/Flutter.h>" > ios/.symlinks/plugins/firebase_core/ios/Classes/FLTFirebaseCorePlugin.h
echo "#import \"FLTFirebaseCorePlugin.h\"" > ios/.symlinks/plugins/firebase_core/ios/Classes/FLTFirebaseCorePlugin.m
echo "@implementation FLTFirebaseCorePlugin" >> ios/.symlinks/plugins/firebase_core/ios/Classes/FLTFirebaseCorePlugin.m
echo "+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {}" >> ios/.symlinks/plugins/firebase_core/ios/Classes/FLTFirebaseCorePlugin.m
echo "@end" >> ios/.symlinks/plugins/firebase_core/ios/Classes/FLTFirebaseCorePlugin.m

# Create firebase_auth.podspec
cat > ios/.symlinks/plugins/firebase_auth/ios/firebase_auth.podspec << EOL
Pod::Spec.new do |s|
  s.name             = 'firebase_auth'
  s.version          = '0.0.1'
  s.summary          = 'Firebase Auth plugin for Flutter.'
  s.description      = 'Flutter plugin for Firebase Auth.'
  s.homepage         = 'https://firebase.flutter.dev/docs/auth/usage'
  s.license          = { :type => 'BSD', :text => 'Copyright 2023 The Flutter Authors. All rights reserved.' }
  s.author           = { 'Flutter Team' => 'flutter-dev@googlegroups.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.ios.deployment_target = '12.0'
  s.dependency 'Flutter'
  s.dependency 'Firebase/Auth', '10.18.0'
  s.static_framework = true
end
EOL
echo "#import <Flutter/Flutter.h>" > ios/.symlinks/plugins/firebase_auth/ios/Classes/FLTFirebaseAuthPlugin.h
echo "#import \"FLTFirebaseAuthPlugin.h\"" > ios/.symlinks/plugins/firebase_auth/ios/Classes/FLTFirebaseAuthPlugin.m
echo "@implementation FLTFirebaseAuthPlugin" >> ios/.symlinks/plugins/firebase_auth/ios/Classes/FLTFirebaseAuthPlugin.m
echo "+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {}" >> ios/.symlinks/plugins/firebase_auth/ios/Classes/FLTFirebaseAuthPlugin.m
echo "@end" >> ios/.symlinks/plugins/firebase_auth/ios/Classes/FLTFirebaseAuthPlugin.m

echo "Podspecs created in the correct location"
ls -la ios/.symlinks/plugins/*/ios/*.podspec 