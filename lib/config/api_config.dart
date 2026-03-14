// import 'package:flutter/foundation.dart';
// const bool isWeb = kIsWeb;
// const String webBaseUrl = "http://10.117.218.135:8000";
// const String desktopBaseUrl = "http://127.0.0.1:8000";
// String get baseUrl => isWeb ? webBaseUrl : desktopBaseUrl;

import 'package:flutter/foundation.dart';

class ApiConfig {
  static String get baseUrl {
    if (kIsWeb) {
      // For web, always use localhost since that's where Django is accepting connections
      return "http://localhost:8000";
    } else {
      // For desktop, also use localhost
      return "http://localhost:8000";
    }
  }
}


// import 'package:flutter/foundation.dart';

// class ApiConfig {
//   static String get baseUrl {
//     if (kIsWeb) {
//       // For web, try using relative URL or localhost
//       return "http://localhost:8000";  // Change this to localhost
//     } else {
//       return "http://10.117.218.135:8000";
//     }
//   }
// }

// import 'package:flutter/foundation.dart';

// class ApiConfig {
//   static const String _webBaseUrl = "http://10.117.218.135:8000";
//   static const String _desktopBaseUrl = "http://127.0.0.1:8000";
  
//   static String get baseUrl {
//     if (kIsWeb) {
//       return _webBaseUrl;
//     } else {
//       return _desktopBaseUrl;
//     }
//   }
  
//   // You can also add other API-related configs here
//   static const int connectionTimeout = 30;
//   static const Map<String, String> defaultHeaders = {
//     'Content-Type': 'application/json',
//   };
// }