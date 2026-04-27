import 'package:flutter/material.dart';
import '../models/contact.dart';
import '../services/api_service.dart';

class ContactsProvider extends ChangeNotifier {
  // List of accepted contacts
  List<Contact> _contacts = [];

  // List of pending contact requests received
  List<Contact> _pendingRequests = [];

  // Search results when looking for new users
  List<dynamic> _searchResults = [];

  bool _isLoading = false;
  bool _isSearching = false;
  String? _error;

  List<Contact> get contacts => _contacts;
  List<Contact> get pendingRequests => _pendingRequests;
  List<dynamic> get searchResults => _searchResults;
  bool get isLoading => _isLoading;
  bool get isSearching => _isSearching;
  String? get error => _error;

  void _notify() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  // ─── Fetch Contacts ──────────────────────────────────────────────────────
  // Loads all accepted contacts for the current user
  Future<void> fetchContacts(String token) async {
    _isLoading = true;
    _error = null;
    _notify();

    try {
      final data = await ApiService.getContacts(token);
      _contacts = data.map((c) => Contact.fromJson(c)).toList();
    } catch (e) {
      _error = 'Failed to load contacts';
    }

    _isLoading = false;
    _notify();
  }

  // ─── Fetch Pending Requests ──────────────────────────────────────────────
  // Loads all pending contact requests received by the current user
  Future<void> fetchPendingRequests(String token) async {
    try {
      final data = await ApiService.getPendingRequests(token);
      _pendingRequests = data.map((c) => Contact.fromJson(c)).toList();
      _notify();
    } catch (e) {
      _error = 'Failed to load pending requests';
      _notify();
    }
  }

  // ─── Search Users ────────────────────────────────────────────────────────
  // Searches for users by username so current user can send contact requests
  Future<void> searchUsers(String token, String query) async {
    // Don't search if query is empty
    if (query.isEmpty) {
      _searchResults = [];
      _notify();
      return;
    }

    _isSearching = true;
    _notify();

    try {
      _searchResults = await ApiService.searchUsers(token, query);
    } catch (e) {
      _error = 'Search failed';
    }

    _isSearching = false;
    _notify();
  }

  // ─── Send Contact Request ────────────────────────────────────────────────
  // Sends a contact request to another user by their ID
  Future<bool> sendContactRequest(String token, int receiverId) async {
    try {
      final data = await ApiService.sendContactRequest(token, receiverId);

      if (data['error'] != null) {
        _error = data['error'];
        _notify();
        return false;
      }

      // Clear search results after sending request
      _searchResults = [];
      _notify();
      return true;
    } catch (e) {
      _error = 'Failed to send contact request';
      _notify();
      return false;
    }
  }

  // ─── Accept Contact Request ──────────────────────────────────────────────
  // Accepts a pending contact request and refreshes contacts list
  Future<bool> acceptContactRequest(String token, int contactId) async {
    try {
      final data = await ApiService.acceptContactRequest(token, contactId);

      if (data['error'] != null) {
        _error = data['error'];
        _notify();
        return false;
      }

      // Refresh both contacts and pending requests after accepting
      await fetchContacts(token);
      await fetchPendingRequests(token);
      return true;
    } catch (e) {
      _error = 'Failed to accept request';
      _notify();
      return false;
    }
  }

  // ─── Remove Contact ──────────────────────────────────────────────────────
  // Removes a contact and refreshes the contacts list
  Future<bool> removeContact(String token, int contactId) async {
    try {
      final data = await ApiService.removeContact(token, contactId);

      if (data['error'] != null) {
        _error = data['error'];
        _notify();
        return false;
      }

      // Refresh contacts list after removal
      await fetchContacts(token);
      _notify();
      return true;
    } catch (e) {
      _error = 'Failed to remove contact';
      _notify();
      return false;
    }
  }

  // ─── Clear Search ────────────────────────────────────────────────────────
  // Clears search results when search bar is dismissed
  void clearSearch() {
    _searchResults = [];
    _notify();
  }
}
