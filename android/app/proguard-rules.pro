# Règles pour Stripe
-keep class com.stripe.android.** { *; }
-keep class com.stripe.android.pushProvisioning.** { *; }
-keepclassmembers class com.stripe.android.pushProvisioning.** { *; }

# Règles spécifiques pour les classes manquantes
-keep class com.stripe.android.pushProvisioning.PushProvisioningActivity { *; }
-keep class com.stripe.android.pushProvisioning.PushProvisioningActivity$** { *; }
-keep class com.stripe.android.pushProvisioning.PushProvisioningActivityStarter { *; }
-keep class com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$** { *; }
-keep class com.stripe.android.pushProvisioning.PushProvisioningEphemeralKeyProvider { *; }

# Règles générales Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Règles pour React Native (utilisées par Stripe)
-keep class com.facebook.react.** { *; }
-keep class com.reactnativestripesdk.** { *; }

# Règles générales Android
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keepattributes Signature
-keepattributes Exceptions