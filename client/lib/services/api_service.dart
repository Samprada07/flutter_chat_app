import 'dart:convert';
import 'package:chat_app/config.dart';
import 'package:http/http.dart' as http;

class ApiService {
  static String get baseUrl => Config.baseUrl;

  // Register
  static Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
      }),
    );

    return jsonDecode(response.body);
  }

  // Login
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    return jsonDecode(response.body);
  }

  // Get all rooms
  static Future<List<dynamic>> getRooms(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/rooms'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    return jsonDecode(response.body);
  }

  // Create a room
  static Future<Map<String, dynamic>> createRoom(
    String token,
    String name,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/rooms'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'name': name}),
    );
    return jsonDecode(response.body);
  }

  // Join a room
  static Future<Map<String, dynamic>> joinRoom(String token, int roomId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/rooms/$roomId/join'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    return jsonDecode(response.body);
  }

  // ─── Contacts ─────────────────────────────────────────────────────────────

  // Search users by username to find and add them as contacts
  static Future<List<dynamic>> searchUsers(String token, String query) async {
    final response = await http.get(
      Uri.parse('$baseUrl/contacts/search?query=$query'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    return jsonDecode(response.body);
  }

  // Send a contact request to another user by their ID
  static Future<Map<String, dynamic>> sendContactRequest(
    String token,
    int receiverId,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/contacts/request'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'receiverId': receiverId}),
    );
    return jsonDecode(response.body);
  }

  // Accept a pending contact request by its ID
  static Future<Map<String, dynamic>> acceptContactRequest(
    String token,
    int contactId,
  ) async {
    final response = await http.put(
      Uri.parse('$baseUrl/contacts/$contactId/accept'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    return jsonDecode(response.body);
  }

  // Get all accepted contacts for the current user
  static Future<List<dynamic>> getContacts(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/contacts'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    return jsonDecode(response.body);
  }

  // Get all pending contact requests received by the current user
  static Future<List<dynamic>> getPendingRequests(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/contacts/pending'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    return jsonDecode(response.body);
  }

  // Remove a contact by their contact ID
  static Future<Map<String, dynamic>> removeContact(
    String token,
    int contactId,
  ) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/contacts/$contactId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    return jsonDecode(response.body);
  }

  // ─── Direct Messages ───────────────────────────────────────────────────────

  // Get all conversations summary for the Chats tab
  // Shows last message and unread count for each contact
  static Future<List<dynamic>> getConversations(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/direct-messages'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    return jsonDecode(response.body);
  }

  // Get full message history with a specific contact
  static Future<List<dynamic>> getConversation(
    String token,
    int contactId,
  ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/direct-messages/$contactId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    return jsonDecode(response.body);
  }

  // Send a direct message to a contact
  static Future<Map<String, dynamic>> sendDirectMessage(
    String token,
    int receiverId,
    String content,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/direct-messages'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'receiverId': receiverId, 'content': content}),
    );
    return jsonDecode(response.body);
  }
}
