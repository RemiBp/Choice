# Keep Stripe push provisioning classes
-keep class com.stripe.android.pushProvisioning.** { *; }
-keep class com.reactnativestripesdk.pushprovisioning.** { *; }

# Règles spécifiques pour les classes manquantes
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivity$g
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Args
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Error
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningEphemeralKeyProvider
-dontwarn com.stripe.android.pushProvisioning.EphemeralKeyUpdateListener

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