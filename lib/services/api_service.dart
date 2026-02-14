import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/buyer.dart';


class BuyerApiService {
  static const String _baseUrl = 'http://127.0.0.1:8000/BusinessPartner/BusinessPartner/Buyers/';

  static Future<List<Buyer>> fetchBuyers() async {
    final response = await http.get(Uri.parse(_baseUrl));
    
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Buyer.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load buyers');
    }
  }
}