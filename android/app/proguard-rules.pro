# Keep Stripe push provisioning classes
-keep class com.stripe.android.pushProvisioning.** { *; }
-keep class com.reactnativestripesdk.pushprovisioning.** { *; }

# Keep general Stripe classes
-keep class com.stripe.android.** { *; }

# Keep Flutter Stripe SDK classes
-keep class com.reactnativestripesdk.** { *; }

# Keep Flutter WebRTC classes
-keep class org.webrtc.** { *; }
-keep class com.cloudwebrtc.webrtc.** { *; }
-keep class io.flutter.plugins.webviewflutter.** { *; }

# Keep Firebase classes
-keep class io.flutter.plugins.firebase.** { *; } 