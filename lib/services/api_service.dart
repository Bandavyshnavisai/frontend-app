import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/item.dart';
import '../services/auth_state.dart';

class ApiService {
  static String get baseUrl {
    String url = dotenv.env['VITE_API_URL'] ?? 'http://localhost:5000';
    if (!kIsWeb && Platform.isAndroid && url.contains('localhost')) {
      return url.replaceAll('localhost', '10.0.2.2');
    }
    return url;
  }

  static Future<Map<String, String>> _getHeaders() async {
    String? token;
    
    // Fake admin bypass (mirrors web frontend axios interceptor)
    if (AuthState.isFakeAdmin) {
      token = 'fake-admin-token';
    } else {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        token = await user.getIdToken(true);
      }
    }

    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Items
  static Future<List<Item>> getItems({String? type}) async {
    final uri = Uri.parse('$baseUrl/api/items${type != null && type != 'all' ? '?type=$type' : ''}');
    final response = await http.get(uri, headers: await _getHeaders());
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // Backend returns `{ data: [...] }`
      final List list = data['data'] ?? [];
      return list.map((e) => Item.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load items');
    }
  }

  static Future<Item> createItem(Map<String, dynamic> itemData) async {
    final uri = Uri.parse('$baseUrl/api/items');
    final response = await http.post(
      uri,
      headers: await _getHeaders(),
      body: jsonEncode(itemData),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return Item.fromJson(data['data'] ?? data);
    } else {
      throw Exception('Failed to create item');
    }
  }

  static Future<void> uploadItemImage(String itemId, String imageBase64) async {
    final uri = Uri.parse('$baseUrl/api/items/$itemId/image');
    final response = await http.post(
      uri,
      headers: await _getHeaders(),
      body: jsonEncode({'image': imageBase64}),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      String errorMessage = 'Failed to upload image';
      try {
        final data = jsonDecode(response.body);
        if (data['message'] != null) {
          errorMessage = data['message'];
        }
      } catch (_) {
        // Fallback to default message
      }
      throw Exception(errorMessage);
    }
  }

  static Future<void> createClaim(String itemId) async {
    final uri = Uri.parse('$baseUrl/api/claims');
    final response = await http.post(
      uri,
      headers: await _getHeaders(),
      body: jsonEncode({'itemId': itemId}),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      String errorMessage = 'Failed to build claim';
      try {
        final data = jsonDecode(response.body);
        if (data['message'] != null) {
          errorMessage = data['message'];
        }
      } catch (_) {
        // Fallback to default message
      }
      throw Exception(errorMessage);
    }
  }

  static Future<List<dynamic>> getMyClaims() async {
    final uri = Uri.parse('$baseUrl/api/claims/my');
    final response = await http.get(uri, headers: await _getHeaders());
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data'] ?? [];
    } else {
      throw Exception('Failed to load my claims');
    }
  }

  static Future<List<dynamic>> getClaimChat(String claimId) async {
    final uri = Uri.parse('$baseUrl/api/claims/$claimId/chat');
    final response = await http.get(uri, headers: await _getHeaders());
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data'] ?? [];
    } else {
      throw Exception('Failed to load chat');
    }
  }

  static Future<void> sendChatMessage(String claimId, String content) async {
    final uri = Uri.parse('$baseUrl/api/claims/$claimId/chat');
    final response = await http.post(
      uri,
      headers: await _getHeaders(),
      body: jsonEncode({'content': content}),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to send message');
    }
  }

  // Profile
  static Future<Map<String, dynamic>> getProfile() async {
    final uri = Uri.parse('$baseUrl/api/users/profile');
    final response = await http.get(uri, headers: await _getHeaders());
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data'] ?? data;
    } else {
      throw Exception('Failed to get profile');
    }
  }

  static Future<void> updateProfile(Map<String, dynamic> profileData) async {
    final uri = Uri.parse('$baseUrl/api/users/profile');
    final response = await http.put(
      uri,
      headers: await _getHeaders(),
      body: jsonEncode(profileData),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to update profile');
    }
  }

  // Admin
  static Future<List<dynamic>> getPendingClaims() async {
    final uri = Uri.parse('$baseUrl/api/admin/claims/pending');
    final response = await http.get(uri, headers: await _getHeaders());
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data'] ?? [];
    } else {
      throw Exception('Failed to get pending claims');
    }
  }

  static Future<List<dynamic>> getEligibleItemsForSale() async {
    final uri = Uri.parse('$baseUrl/api/admin/sale/eligible-items');
    final response = await http.get(uri, headers: await _getHeaders());
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data'] ?? [];
    } else {
      throw Exception('Failed to get eligible items for marketplace');
    }
  }

  static Future<List<dynamic>> getClaimsByStatus(String status) async {
    final uri = Uri.parse('$baseUrl/api/admin/claims/status/$status');
    final response = await http.get(uri, headers: await _getHeaders());
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data'] ?? [];
    } else {
      throw Exception('Failed to get claims for status: $status');
    }
  }

  static Future<void> approveClaim(String claimId, {String? remarks}) async {
    final uri = Uri.parse('$baseUrl/api/admin/claims/$claimId/approve');
    final response = await http.post(
      uri,
      headers: await _getHeaders(),
      body: jsonEncode({'remarks': remarks ?? ''}),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to approve claim');
    }
  }

  static Future<void> rejectClaim(String claimId, {String? remarks}) async {
    final uri = Uri.parse('$baseUrl/api/admin/claims/$claimId/reject');
    final response = await http.post(
      uri,
      headers: await _getHeaders(),
      body: jsonEncode({'remarks': remarks ?? ''}),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to reject claim');
    }
  }

  static Future<Map<String, dynamic>> getAnalytics() async {
    final uri = Uri.parse('$baseUrl/api/admin/analytics');
    final response = await http.get(uri, headers: await _getHeaders());
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data'] ?? data;
    } else {
      throw Exception('Failed to get analytics');
    }
  }

  static Future<Map<String, dynamic>> getClaimAnalytics() async {
    final uri = Uri.parse('$baseUrl/api/admin/claims/analytics');
    final response = await http.get(uri, headers: await _getHeaders());
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data'] ?? data;
    } else {
      // Fallback: derive from pending claims count
      return {};
    }
  }

  static Future<void> reopenClaim(String claimId) async {
    final uri = Uri.parse('$baseUrl/api/admin/claims/$claimId/reopen');
    final response = await http.post(uri, headers: await _getHeaders());
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to reopen claim');
    }
  }

  static Future<void> addClaimNote(String claimId, String note) async {
    final uri = Uri.parse('$baseUrl/api/admin/claims/$claimId/note');
    final response = await http.post(uri, headers: await _getHeaders(), body: jsonEncode({'note': note}));
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to add note');
    }
  }

  static Future<Map<String, dynamic>> getClaimEvidence(String claimId) async {
    final uri = Uri.parse('$baseUrl/api/admin/claims/$claimId/evidence');
    final response = await http.get(uri, headers: await _getHeaders());
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data'] ?? data;
    } else {
      throw Exception('Failed to load evidence');
    }
  }

  static Future<void> requestProof(String claimId) async {
    final uri = Uri.parse('$baseUrl/api/admin/claims/$claimId/request-proof');
    final response = await http.post(uri, headers: await _getHeaders());
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to request proof');
    }
  }

  static Future<void> approveSale(String itemId, double price) async {
    final uri = Uri.parse('$baseUrl/api/admin/items/$itemId/approve-sale');
    final response = await http.post(uri, headers: await _getHeaders(), body: jsonEncode({'price': price}));
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to approve sale');
    }
  }

  static Future<void> seedCctvLogs() async {
    final uri = Uri.parse('$baseUrl/api/cctv/seed-logs');
    final response = await http.post(uri, headers: await _getHeaders());
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to seed CCTV logs');
    }
  }

  // My Items
  static Future<List<dynamic>> getMyItems() async {
    final uri = Uri.parse('$baseUrl/api/items/my');
    final response = await http.get(uri, headers: await _getHeaders());
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data'] ?? [];
    } else {
      throw Exception('Failed to load my items');
    }
  }

  static Future<void> updateItem(String itemId, Map<String, dynamic> updates) async {
    final uri = Uri.parse('$baseUrl/api/items/$itemId');
    final response = await http.put(
      uri,
      headers: await _getHeaders(),
      body: jsonEncode(updates),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      String msg = 'Failed to update item';
      try { final d = jsonDecode(response.body); if (d['message'] != null) msg = d['message']; } catch (_) {}
      throw Exception(msg);
    }
  }

  static Future<void> deleteItem(String itemId) async {
    final uri = Uri.parse('$baseUrl/api/items/$itemId');
    final response = await http.delete(uri, headers: await _getHeaders());
    if (response.statusCode != 200 && response.statusCode != 204) {
      String msg = 'Failed to delete item';
      try { final d = jsonDecode(response.body); if (d['message'] != null) msg = d['message']; } catch (_) {}
      throw Exception(msg);
    }
  }

  // Sale
  static Future<void> buyItem(String itemId) async {
    final uri = Uri.parse('$baseUrl/api/sale/buy');
    final response = await http.post(
      uri,
      headers: await _getHeaders(),
      body: jsonEncode({'itemId': itemId}),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      String msg = 'Failed to purchase item';
      try { final d = jsonDecode(response.body); if (d['message'] != null || d['error'] != null) msg = d['message'] ?? d['error']; } catch (_) {}
      throw Exception(msg);
    }
  }

  // AI Features
  static Future<void> extractFeatures(String itemId, String collection) async {
    final uri = Uri.parse('$baseUrl/api/ai/extract-features/$itemId/$collection');
    final response = await http.post(uri, headers: await _getHeaders());
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to extract features');
    }
  }

  static Future<void> compareAndSuggest(String itemId, String collection) async {
    final uri = Uri.parse('$baseUrl/api/ai/compare-and-suggest/$itemId/$collection');
    final response = await http.post(uri, headers: await _getHeaders());
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to compare items');
    }
  }

  /// Like compareAndSuggest but returns the full list of suggestion objects.
  static Future<List<dynamic>> compareAndSuggestFull(String itemId, String collection) async {
    final uri = Uri.parse('$baseUrl/api/ai/compare-and-suggest/$itemId/$collection');
    final response = await http.post(uri, headers: await _getHeaders());
    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return (data['data'] as List?) ?? [];
    } else {
      String msg = 'Failed to compare items';
      try { final d = jsonDecode(response.body); if (d['error'] != null) msg = d['error']; } catch (_) {}
      throw Exception(msg);
    }
  }
  
  static Future<Map<String, dynamic>> compareCustomImage(String itemId, String imageBase64) async {
    final uri = Uri.parse('$baseUrl/api/ai/compare-custom-image/$itemId');
    final response = await http.post(
      uri,
      headers: await _getHeaders(),
      body: jsonEncode({'image': imageBase64}),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return data['data'] ?? data;
    } else {
      String msg = 'Failed to compare custom image';
      try { final d = jsonDecode(response.body); if (d['error'] != null) msg = d['error']; } catch (_) {}
      throw Exception(msg);
    }
  }

  // CCTV Verification (admin only)
  static Future<List<dynamic>> getCctvLogs({String? zone}) async {
    final query = zone != null ? '?zone=${Uri.encodeComponent(zone)}' : '';
    final uri = Uri.parse('$baseUrl/api/cctv/logs$query');
    final response = await http.get(uri, headers: await _getHeaders());
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['data'] as List?) ?? [];
    } else {
      throw Exception('Failed to load CCTV logs');
    }
  }

  static Future<Map<String, dynamic>> verifyClaim(String claimId) async {
    final uri = Uri.parse('$baseUrl/api/cctv/verify-claim/$claimId');
    final response = await http.post(uri, headers: await _getHeaders());
    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return data['data'] ?? data;
    } else {
      String msg = 'Verification failed';
      try { final d = jsonDecode(response.body); if (d['error'] != null) msg = d['error']; } catch (_) {}
      throw Exception(msg);
    }
  }

  static Future<Map<String, dynamic>> getCctvVerificationResult(String claimId) async {
    final uri = Uri.parse('$baseUrl/api/cctv/verification-result/$claimId');
    final response = await http.get(uri, headers: await _getHeaders());
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data'] ?? data;
    } else if (response.statusCode == 404) {
      throw Exception('No verification result found');
    } else {
      String msg = 'Failed to get verification result';
      try { final d = jsonDecode(response.body); if (d['error'] != null) msg = d['error']; } catch (_) {}
      throw Exception(msg);
    }
  }
}

