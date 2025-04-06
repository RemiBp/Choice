package fr.remibp.contactsservice;

import androidx.annotation.NonNull;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

/** ContactsServicePlugin */
public class ContactsServicePlugin implements FlutterPlugin, MethodCallHandler {
  /// The MethodChannel that will the communication between Flutter and native Android
  private MethodChannel channel;

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
    channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "contacts_service");
    channel.setMethodCallHandler(this);
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
    // Implémentation simulée - renvoie juste des réponses vides ou simulées
    switch (call.method) {
      case "getContacts":
        // Dans une implémentation réelle, on récupérerait les contacts du téléphone
        result.success(new java.util.ArrayList<>());
        break;
      case "getContact":
        // Dans une implémentation réelle, on récupérerait un contact spécifique
        result.success(new java.util.HashMap<>());
        break;
      case "addContact":
        // Dans une implémentation réelle, on ajouterait un contact
        result.success(null);
        break;
      case "deleteContact":
        // Dans une implémentation réelle, on supprimerait un contact
        result.success(null);
        break;
      case "updateContact":
        // Dans une implémentation réelle, on mettrait à jour un contact
        result.success(null);
        break;
      case "inviteContact":
        // Dans une implémentation réelle, on enverrait un SMS d'invitation
        String phoneNumber = call.argument("phoneNumber");
        String message = call.argument("message");
        // Simulation d'une invitation par SMS
        result.success(true);
        break;
      default:
        result.notImplemented();
        break;
    }
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    channel.setMethodCallHandler(null);
  }
} 