import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/contacts_provider.dart';
import '../models/contact.dart';

class ContactsScreen extends StatefulWidget {
  // Called from HomeScreen to toggle search
  final bool showSearch;

  const ContactsScreen({super.key, required this.showSearch});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final token = context.read<AuthProvider>().user?.token ?? '';
      context.read<ContactsProvider>().fetchContacts(token);
      context.read<ContactsProvider>().fetchPendingRequests(token);
    });
  }

  @override
  void didUpdateWidget(ContactsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Clear search when search is toggled off
    if (!widget.showSearch) {
      _searchController.clear();
      context.read<ContactsProvider>().clearSearch();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    final token = context.read<AuthProvider>().user?.token ?? '';
    context.read<ContactsProvider>().searchUsers(token, query);
  }

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
                ? 'Request sent to $username!'
                : context.read<ContactsProvider>().error ?? 'Failed',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

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

    return Column(
      children: [
        // Show search bar below appbar when search is active
        if (widget.showSearch)
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search users...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: _onSearchChanged,
            ),
          ),

        // Body content
        Expanded(
          child: contacts.isLoading
              ? const Center(child: CircularProgressIndicator())
              : widget.showSearch
              ? _buildSearchResults(contacts)
              : _buildContactsList(contacts),
        ),
      ],
    );
  }

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

        // Check if this user is already a contact
        final isAlreadyContact = contacts.contacts.any(
          (c) => c.userId == user['id'],
        );

        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue.shade100,
              child: Text(
                user['username'][0].toUpperCase(),
                style: const TextStyle(color: Colors.blue),
              ),
            ),
            title: Text(user['username']),
            subtitle: Text(user['email']),
            trailing: isAlreadyContact
                // Show nothing if already a contact
                ? null
                // Show Add button if not a contact
                : ElevatedButton(
                    onPressed: () => _sendRequest(user['id'], user['username']),
                    child: const Text('Add'),
                  ),
          ),
        );
      },
    );
  }

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
            onTap: () {
              // Will wire to direct chat in Commit 17
            },
          ),
        );
      },
    );
  }
}
