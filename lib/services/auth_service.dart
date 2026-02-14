import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class AuthService {
  AuthService._privateConstructor();
  static final AuthService instance = AuthService._privateConstructor();

  String? token;
  String? sessionId;
  String? fullName;
  String? role;
  String? userCode;
  String? email;
  String? profilePicture;

  Future<bool> login(String identifier, String userInputPassword) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/user/reslogin/"),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email_or_mobile_or_user_code': identifier,
          'password': userInputPassword,
        }),
      );

      final data = jsonDecode(response.body);
      print("📦 Login API Response: $data");

      if (response.statusCode == 200 && data['token'] != null) {
        token = data['token'];
        sessionId = data['session_id'];
        fullName = data['full_name'];
        role = data['role'];
        userCode = data['user_code'];
        email = data['email'];
        profilePicture = data['profile_picture'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', token!);
        await prefs.setString('session_id', sessionId ?? '');
        await prefs.setString('full_name', fullName ?? '');
        await prefs.setString('role', role ?? '');
        await prefs.setString('user_code', userCode ?? '');
        await prefs.setString('email', email ?? '');
        await prefs.setString('profile_picture', profilePicture ?? '');

        print("✅ Login Success");
        return true;
      } else {
        print("❌ Login Failed: ${data['message']}");
        return false;
      }
    } catch (e) {
      print("❌ Login Error: $e");
      return false;
    }
  }

  Future<void> loadUserFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('token');
    sessionId = prefs.getString('session_id');
    fullName = prefs.getString('full_name');
    role = prefs.getString('role');
    userCode = prefs.getString('user_code');
    email = prefs.getString('email');
    profilePicture = prefs.getString('profile_picture');
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    token = null;
    sessionId = null;
    fullName = null;
    role = null;
    userCode = null;
    email = null;
    profilePicture = null;
    print("🧹 Logged out & cleared storage");
  }
}


// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import 'package:shared_preferences/shared_preferences.dart';

// class AuthService {
//   AuthService._privateConstructor();
//   static final AuthService instance = AuthService._privateConstructor();

//   final String loginUrl = 'http://127.0.0.1:8000/user/reslogin/';

//   String? token;
//   String? sessionId;
//   String? fullName;
//   String? role;
//   String? userCode;
//   String? email;
//   String? profilePicture;

//   Future<bool> login(String identifier, String userInputPassword) async {
//     try {
//       final response = await http.post(
//         Uri.parse(loginUrl),
//         headers: {
//           'Content-Type': 'application/json',
//         },
//         body: jsonEncode({
//           'email_or_mobile_or_user_code': identifier,
//           'password': userInputPassword,
//         }),
//       );

//       final data = jsonDecode(response.body);
//       print("📦 Login API Response: $data");

//       if (response.statusCode == 200 && data['token'] != null) {
//         token = data['token'];
//         sessionId = data['session_id'];
//         fullName = data['full_name'];
//         role = data['role'];
//         userCode = data['user_code'];
//         email = data['email'];
//         profilePicture = data['profile_picture'];
//         final prefs = await SharedPreferences.getInstance();
//         await prefs.setString('token', token!);
//         await prefs.setString('session_id', sessionId ?? '');
//         await prefs.setString('full_name', fullName ?? '');
//         await prefs.setString('role', role ?? '');
//         await prefs.setString('user_code', userCode ?? '');
//         await prefs.setString('email', email ?? '');
//         await prefs.setString('profile_picture', profilePicture ?? '');

//         print("✅ Login Success");
//         return true;
//       } else {
//         print("❌ Login Failed: ${data['message']}");
//         return false;
//       }
//     } catch (e) {
//       print("❌ Login Error: $e");
//       return false;
//     }
//   }

//   Future<void> loadUserFromStorage() async {
//     final prefs = await SharedPreferences.getInstance();
//     token = prefs.getString('token');
//     sessionId = prefs.getString('session_id');
//     fullName = prefs.getString('full_name');
//     role = prefs.getString('role');
//     userCode = prefs.getString('user_code');
//     email = prefs.getString('email');
//     profilePicture = prefs.getString('profile_picture');
//   }

//   Future<String?> getToken() async {
//     final prefs = await SharedPreferences.getInstance();
//     return prefs.getString('token');
//   }

//   Future<void> logout() async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.clear();
//     token = null;
//     sessionId = null;
//     fullName = null;
//     role = null;
//     userCode = null;
//     email = null;
//     profilePicture = null;
//     print("🧹 Logged out & cleared storage");
//   }
// }
