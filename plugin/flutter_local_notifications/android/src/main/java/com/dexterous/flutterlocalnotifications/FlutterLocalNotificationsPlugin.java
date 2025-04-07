package com.dexterous.flutterlocalnotifications;

import android.app.Notification;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.ActivityManager;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.SharedPreferences;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Color;
import android.net.Uri;
import android.os.Bundle;
import android.os.Build;
import android.service.notification.StatusBarNotification;
import android.text.Html;
import android.text.Spanned;
import android.widget.RemoteViews;
import android.app.NotificationChannel;
import android.app.NotificationChannelGroup;
import androidx.annotation.DrawableRes;
import androidx.annotation.Keep;
import androidx.annotation.NonNull;
import androidx.core.app.AlarmManagerCompat;
import androidx.core.app.NotificationCompat;
import androidx.core.app.NotificationManagerCompat;
import androidx.core.app.Person;
import androidx.core.graphics.drawable.IconCompat;

import java.io.FileInputStream;
import java.io.IOException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.NewIntentListener;

public class FlutterLocalNotificationsPlugin implements MethodCallHandler, FlutterPlugin {
    private static final String METHOD_CHANNEL = "dexterous.com/flutter/local_notifications";
    private MethodChannel channel;
    private Context applicationContext;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPlugin.FlutterPluginBinding binding) {
        channel = new MethodChannel(binding.getBinaryMessenger(), METHOD_CHANNEL);
        applicationContext = binding.getApplicationContext();
        channel.setMethodCallHandler(this);
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPlugin.FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
        channel = null;
        applicationContext = null;
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        switch (call.method) {
            case "initialize":
                initialize(call, result);
                break;
            case "show":
                show(call, result);
                break;
            case "cancel":
                cancel(call, result);
                break;
            case "cancelAll":
                cancelAll(call, result);
                break;
            default:
                result.notImplemented();
                break;
        }
    }

    private void initialize(MethodCall call, Result result) {
        // Implémentation de base pour initialize
        result.success(true);
    }

    private void show(MethodCall call, Result result) {
        // Implémentation de base pour show
        result.success(null);
    }

    private void cancel(MethodCall call, Result result) {
        // Implémentation de base pour cancel
        result.success(null);
    }

    private void cancelAll(MethodCall call, Result result) {
        // Implémentation de base pour cancelAll
        result.success(null);
    }

    private void configureNotificationStyleBigPicture(
            NotificationCompat.Builder builder,
            Map<String, Object> bigPictureStyleInformation) {
        // Créer le style
        NotificationCompat.BigPictureStyle bigPictureStyle = new NotificationCompat.BigPictureStyle();

        // Configuration de base
        if (bigPictureStyleInformation.containsKey("contentTitle")) {
            bigPictureStyle.setBigContentTitle((String) bigPictureStyleInformation.get("contentTitle"));
        }

        if (bigPictureStyleInformation.containsKey("summaryText")) {
            bigPictureStyle.setSummaryText((String) bigPictureStyleInformation.get("summaryText"));
        }

        // Correction de l'ambiguïté
        if (bigPictureStyleInformation.containsKey("hideExpandedLargeIcon")) {
            Boolean hideExpandedLargeIcon = (Boolean) bigPictureStyleInformation.get("hideExpandedLargeIcon");
            if (hideExpandedLargeIcon) {
                // Corriger l'ambiguïté en utilisant explicitement la méthode bigLargeIcon(Bitmap)
                bigPictureStyle.bigLargeIcon((Bitmap) null);
            }
        }
        
        // Appliquer le style à la notification
        builder.setStyle(bigPictureStyle);
    }
} 