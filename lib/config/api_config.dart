import 'package:flutter/foundation.dart';
const bool isWeb = kIsWeb;
const String webBaseUrl = "http://10.117.218.135:8000";
const String desktopBaseUrl = "http://127.0.0.1:8000";
String get baseUrl => isWeb ? webBaseUrl : desktopBaseUrl;
