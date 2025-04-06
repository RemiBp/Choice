package fr.g123k.flutterappbadger;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;

import androidx.annotation.NonNull;

import java.util.List;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

/** FlutterAppBadgerPlugin */
public class FlutterAppBadgerPlugin implements FlutterPlugin, MethodCallHandler, ActivityAware {
  private MethodChannel channel;
  private Context context;
  private Activity activity;

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
    channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "flutter_app_badger");
    channel.setMethodCallHandler(this);
    context = flutterPluginBinding.getApplicationContext();
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
    if (call.method.equals("updateBadgeCount")) {
      int count = call.argument("count");
      updateBadgeCount(count);
      result.success(null);
    } else if (call.method.equals("removeBadge")) {
      removeBadge();
      result.success(null);
    } else if (call.method.equals("isAppBadgeSupported")) {
      result.success(isAppBadgeSupported());
    } else {
      result.notImplemented();
    }
  }

  private void updateBadgeCount(int count) {
    // Cette implémentation est simplifiée - vous devrez adapter selon les besoins
    // Simuler une version de base pour le moment
    if (context != null) {
      Intent intent = new Intent("android.intent.action.BADGE_COUNT_UPDATE");
      intent.putExtra("badge_count", count);
      intent.putExtra("badge_count_package_name", context.getPackageName());
      intent.putExtra("badge_count_class_name", getLauncherClassName());
      context.sendBroadcast(intent);
    }
  }

  private void removeBadge() {
    updateBadgeCount(0);
  }

  private boolean isAppBadgeSupported() {
    // Vérification simplifiée - vous devrez adapter selon les besoins
    return true;
  }

  private String getLauncherClassName() {
    if (context == null) {
      return "";
    }

    PackageManager pm = context.getPackageManager();
    Intent intent = new Intent(Intent.ACTION_MAIN);
    intent.addCategory(Intent.CATEGORY_LAUNCHER);

    List<ResolveInfo> resolveInfos = pm.queryIntentActivities(intent, 0);
    for (ResolveInfo resolveInfo : resolveInfos) {
      String pkgName = resolveInfo.activityInfo.applicationInfo.packageName;
      if (pkgName.equalsIgnoreCase(context.getPackageName())) {
        return resolveInfo.activityInfo.name;
      }
    }
    return "";
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    channel.setMethodCallHandler(null);
    context = null;
  }

  @Override
  public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
    activity = binding.getActivity();
  }

  @Override
  public void onDetachedFromActivityForConfigChanges() {
    activity = null;
  }

  @Override
  public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
    activity = binding.getActivity();
  }

  @Override
  public void onDetachedFromActivity() {
    activity = null;
  }
} 