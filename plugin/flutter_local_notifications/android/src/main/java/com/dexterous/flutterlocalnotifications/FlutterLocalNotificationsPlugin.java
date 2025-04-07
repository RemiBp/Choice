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
    // ... (Code existant)

    private void configureNotificationStyleBigPicture(
            NotificationCompat.Builder builder,
            Map<String, Object> bigPictureStyleInformation) {
        // ... (Code existant)

        if (bigPictureStyleInformation.containsKey("hideExpandedLargeIcon")) {
            Boolean hideExpandedLargeIcon = (Boolean) bigPictureStyleInformation.get("hideExpandedLargeIcon");
            if (hideExpandedLargeIcon) {
                // Corriger l'ambiguïté en utilisant explicitement la méthode bigLargeIcon(Bitmap)
                bigPictureStyle.bigLargeIcon((Bitmap) null);
            }
        }
        
        // ... (Reste du code)
    }

    // ... (Reste de la classe)
} 