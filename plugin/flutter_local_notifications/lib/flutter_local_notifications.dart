import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:timezone/timezone.dart';

// Classe principale du plugin
class FlutterLocalNotificationsPlugin {
  static const MethodChannel _channel =
      MethodChannel('dexterous.com/flutter/local_notifications');

  /// Initialise le plugin.
  Future<bool?> initialize(
    InitializationSettings initializationSettings, {
    Function(NotificationResponse)? onDidReceiveNotificationResponse,
    Function(NotificationResponse)? onDidReceiveBackgroundNotificationResponse,
  }) async {
    // Implémentation simplifiée pour contourner l'erreur
    try {
      return await _channel.invokeMethod('initialize');
    } catch (e) {
      print('Error initializing notifications: $e');
      return false;
    }
  }

  /// Affiche une notification
  Future<void> show(
    int id,
    String? title,
    String? body,
    NotificationDetails? notificationDetails, {
    String? payload,
  }) async {
    try {
      await _channel.invokeMethod('show', <String, dynamic>{
        'id': id,
        'title': title,
        'body': body,
        'platformSpecifics': notificationDetails != null
            ? _retrievePlatformSpecificNotificationDetails(notificationDetails)
            : null,
        'payload': payload ?? '',
      });
    } catch (e) {
      print('Error showing notification: $e');
    }
  }

  /// Annule une notification spécifique
  Future<void> cancel(int id) async {
    try {
      await _channel.invokeMethod('cancel', id);
    } catch (e) {
      print('Error cancelling notification: $e');
    }
  }

  /// Annule toutes les notifications
  Future<void> cancelAll() async {
    try {
      await _channel.invokeMethod('cancelAll');
    } catch (e) {
      print('Error cancelling all notifications: $e');
    }
  }

  Map<String, dynamic>? _retrievePlatformSpecificNotificationDetails(
      NotificationDetails notificationDetails) {
    if (Platform.isAndroid) {
      return notificationDetails.android?.toMap();
    } else if (Platform.isIOS) {
      return notificationDetails.iOS?.toMap();
    } else if (Platform.isMacOS) {
      return notificationDetails.macOS?.toMap();
    }
    return null;
  }
}

// Classes de support
class InitializationSettings {
  final AndroidInitializationSettings? android;
  final DarwinInitializationSettings? iOS;
  final DarwinInitializationSettings? macOS;
  final LinuxInitializationSettings? linux;

  const InitializationSettings({
    this.android,
    this.iOS,
    this.macOS,
    this.linux,
  });
}

class AndroidInitializationSettings {
  final String? defaultIcon;
  final bool requestAlertPermission;
  final bool requestSoundPermission;
  final bool requestBadgePermission;
  final bool defaultPresentAlert;
  final bool defaultPresentSound;
  final bool defaultPresentBadge;

  const AndroidInitializationSettings({
    this.defaultIcon,
    this.requestAlertPermission = true,
    this.requestSoundPermission = true,
    this.requestBadgePermission = true,
    this.defaultPresentAlert = true,
    this.defaultPresentSound = true,
    this.defaultPresentBadge = true,
  });
}

class DarwinInitializationSettings {
  final String? defaultPresentSound;
  final String? defaultPresentBadge;
  final String? defaultPresentAlert;

  const DarwinInitializationSettings({
    this.defaultPresentSound = 'true',
    this.defaultPresentBadge = 'true',
    this.defaultPresentAlert = 'true',
  });
}

class LinuxInitializationSettings {
  final String? defaultActionName;

  const LinuxInitializationSettings({
    this.defaultActionName = 'Open notification',
  });
}

class NotificationDetails {
  final AndroidNotificationDetails? android;
  final DarwinNotificationDetails? iOS;
  final DarwinNotificationDetails? macOS;
  final LinuxNotificationDetails? linux;

  const NotificationDetails({
    this.android,
    this.iOS,
    this.macOS,
    this.linux,
  });
}

class AndroidNotificationDetails {
  final String channelId;
  final String channelName;
  final String? channelDescription;
  final String? icon;
  final int importance;
  final int priority;
  final String? sound;
  final bool playSound;
  final bool enableVibration;
  final bool enableLights;
  final Color? color;
  final String? largeIcon;
  final String? bigPicture;
  final String? styleInformation;
  final bool? autoCancel;
  final String? groupKey;
  final String? ticker;
  final String? subText;

  const AndroidNotificationDetails(
    this.channelId,
    this.channelName, {
    this.channelDescription,
    this.icon,
    this.importance = 4,
    this.priority = 1,
    this.sound,
    this.playSound = true,
    this.enableVibration = true,
    this.enableLights = true,
    this.color,
    this.largeIcon,
    this.bigPicture,
    this.styleInformation,
    this.autoCancel = true,
    this.groupKey,
    this.ticker,
    this.subText,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'channelId': channelId,
      'channelName': channelName,
      'channelDescription': channelDescription,
      'icon': icon,
      'importance': importance,
      'priority': priority,
      'sound': sound,
      'playSound': playSound,
      'enableVibration': enableVibration,
      'enableLights': enableLights,
      'color': color?.value,
      'largeIcon': largeIcon,
      'bigPicture': bigPicture,
      'styleInformation': styleInformation,
      'autoCancel': autoCancel,
      'groupKey': groupKey,
      'ticker': ticker,
      'subText': subText,
    };
  }
}

class DarwinNotificationDetails {
  final String? sound;
  final String? presentSound;
  final String? presentBadge;
  final String? presentAlert;
  final String? subtitle;
  final String? threadIdentifier;
  final Map<String, dynamic>? categoryIdentifier;

  const DarwinNotificationDetails({
    this.sound,
    this.presentSound,
    this.presentBadge,
    this.presentAlert,
    this.subtitle,
    this.threadIdentifier,
    this.categoryIdentifier,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'sound': sound,
      'presentSound': presentSound,
      'presentBadge': presentBadge,
      'presentAlert': presentAlert,
      'subtitle': subtitle,
      'threadIdentifier': threadIdentifier,
      'categoryIdentifier': categoryIdentifier,
    };
  }
}

class LinuxNotificationDetails {
  final String? actionName;
  final String? defaultActionName;
  final String? icon;
  final String? sound;
  final int? urgency;
  final int? timeout;

  const LinuxNotificationDetails({
    this.actionName,
    this.defaultActionName,
    this.icon,
    this.sound,
    this.urgency,
    this.timeout,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'actionName': actionName,
      'defaultActionName': defaultActionName,
      'icon': icon,
      'sound': sound,
      'urgency': urgency,
      'timeout': timeout,
    };
  }
}

class NotificationResponse {
  final String? notificationResponseType;
  final int id;
  final String? payload;

  const NotificationResponse({
    this.notificationResponseType,
    required this.id,
    this.payload,
  });
} 