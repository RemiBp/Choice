// Interface class for the flutter_local_notifications plugin
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

abstract class FlutterLocalNotificationsPlatform extends PlatformInterface {
  FlutterLocalNotificationsPlatform() : super(token: _token);

  static final Object _token = Object();
  static FlutterLocalNotificationsPlatform? _instance;

  static FlutterLocalNotificationsPlatform get instance => _instance!;

  static set instance(FlutterLocalNotificationsPlatform instance) {
    _instance = instance;
  }
} 