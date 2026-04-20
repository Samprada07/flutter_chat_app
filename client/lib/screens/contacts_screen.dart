import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/contacts_provider.dart';
import '../models/contact.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final _searchController = TextEditingController();

  // Controls whether the search bar is visible
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();

    // Load contacts and pending requests when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final token = context.read<AuthProvider>().user?.token ?? '';
      context.read<ContactsProvider>().fetchContacts(token);
      context.read<ContactsProvider>().fetchPendingRequests(token);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ─── Search Users ────────────────────────────────────────────────────────
  // Triggered on every keystroke in the search bar
  void _onSearchChanged(String query) {
    final token = context.read<AuthProvider>().user?.token ?? '';
    context.read<ContactsProvider>().searchUsers(token, query);
  }

  // ─── Send Contact Request ────────────────────────────────────────────────
  // Sends a contact request and shows a snackbar with result
  Future<void> _sendRequest(int receiverId, String username) async {
    final token = context.read<AuthProvider>().user?.token ?? '';
    final success = await context.read<ContactsProvider>().sendContactRequest(
      token,
      receiverId,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Contact request sent to $username!'
                : context.read<ContactsProvider>().error ?? 'Failed',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  // ─── Remove Contact Dialog ───────────────────────────────────────────────
  // Shows confirmation dialog before removing a contact
  void _showRemoveDialog(Contact contact) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Contact'),
        content: Text('Remove ${contact.username} from contacts?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final token = context.read<AuthProvider>().user?.token ?? '';
              await context.read<ContactsProvider>().removeContact(
                token,
                contact.contactId,
              );
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final contacts = context.watch<ContactsProvider>();
    final pendingCount = contacts.pendingRequests.length;

    // No Scaffold here — HomeScreen already provides it
    return contacts.isLoading
        ? const Center(child: CircularProgressIndicator())
        : _showSearch
        ? _buildSearchResults(contacts)
        : _buildContactsList(contacts);
  }

  // ─── Search Results Widget ───────────────────────────────────────────────
  // Shows users found by search with an Add button
  Widget _buildSearchResults(ContactsProvider contacts) {
    if (contacts.isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (contacts.searchResults.isEmpty) {
      return const Center(
        child: Text('No users found', style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: contacts.searchResults.length,
      itemBuilder: (context, index) {
        final user = contacts.searchResults[index];
        return Card(
          child: ListTile(
            // User avatar with first letter of username
            leading: CircleAvatar(
              backgroundColor: Colors.blue.shade100,
              child: Text(
                user['username'][0].toUpperCase(),
                style: const TextStyle(color: Colors.blue),
              ),
            ),
            title: Text(user['username']),
            subtitle: Text(user['email']),
            trailing: ElevatedButton(
              onPressed: () => _sendRequest(user['id'], user['username']),
              child: const Text('Add'),
            ),
          ),
        );
      },
    );
  }

  // ─── Contacts List Widget ────────────────────────────────────────────────
  // Shows all accepted contacts with option to remove
  Widget _buildContactsList(ContactsProvider contacts) {
    if (contacts.contacts.isEmpty) {
      return const Center(
        child: Text(
          'No contacts yet.\nSearch for users to add!',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: contacts.contacts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final contact = contacts.contacts[index];
        return Card(
          child: ListTile(
            // Contact avatar with first letter of username
            leading: CircleAvatar(
              backgroundColor: Colors.green.shade100,
              child: Text(
                contact.username[0].toUpperCase(),
                style: const TextStyle(color: Colors.green),
              ),
            ),
            title: Text(
              contact.username,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(contact.email),
            trailing: IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () => _showRemoveDialog(contact),
            ),
            // Navigate to direct chat on tap
            onTap: () {
              // Will be wired in Commit 17
            },
          ),
        );
      },
    );
  }
}
