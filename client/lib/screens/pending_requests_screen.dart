import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/contacts_provider.dart';

class PendingRequestsScreen extends StatefulWidget {
  const PendingRequestsScreen({super.key});

  @override
  State<PendingRequestsScreen> createState() => _PendingRequestsScreenState();
}

class _PendingRequestsScreenState extends State<PendingRequestsScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch pending requests when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final token = context.read<AuthProvider>().user?.token ?? '';
      context.read<ContactsProvider>().fetchPendingRequests(token);
    });
  }

  // ─── Accept Request ──────────────────────────────────────────────────────
  // Accepts a pending contact request and shows result snackbar
  Future<void> _acceptRequest(int contactId, String username) async {
    final token = context.read<AuthProvider>().user?.token ?? '';
    final success = await context.read<ContactsProvider>().acceptContactRequest(
      token,
      contactId,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? '$username added to contacts!'
                : context.read<ContactsProvider>().error ?? 'Failed',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  // ─── Decline Request ─────────────────────────────────────────────────────
  // Declines a pending contact request by removing it
  Future<void> _declineRequest(int contactId, String username) async {
    final token = context.read<AuthProvider>().user?.token ?? '';
    await context.read<ContactsProvider>().removeContact(token, contactId);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request from $username declined')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final contacts = context.watch<ContactsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Pending Requests')),
      body: contacts.isLoading
          ? const Center(child: CircularProgressIndicator())
          : contacts.pendingRequests.isEmpty
          ? const Center(
              child: Text(
                'No pending requests',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: contacts.pendingRequests.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final request = contacts.pendingRequests[index];
                return Card(
                  child: ListTile(
                    // Avatar with first letter of username
                    leading: CircleAvatar(
                      backgroundColor: Colors.orange.shade100,
                      child: Text(
                        request.username[0].toUpperCase(),
                        style: const TextStyle(color: Colors.orange),
                      ),
                    ),
                    title: Text(
                      request.username,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(request.email),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Accept button
                        IconButton(
                          icon: const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                          ),
                          onPressed: () => _acceptRequest(
                            request.contactId,
                            request.username,
                          ),
                        ),
                        // Decline button
                        IconButton(
                          icon: const Icon(Icons.cancel, color: Colors.red),
                          onPressed: () => _declineRequest(
                            request.contactId,
                            request.username,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
