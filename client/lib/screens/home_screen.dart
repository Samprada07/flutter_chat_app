import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/rooms_provider.dart';
import '../models/room.dart';
import 'group_chat_screen.dart';
import 'contacts_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _roomNameController = TextEditingController();

  // Controls which tab is active: 0 = Rooms, 1 = Contacts
  int _currentIndex = 0;

  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final token = context.read<AuthProvider>().user?.token ?? '';
      context.read<RoomsProvider>().fetchRooms(token);
    });
  }

  @override
  void dispose() {
    _roomNameController.dispose();
    super.dispose();
  }

  // ─── Create Room Dialog ──────────────────────────────────────────────────
  void _showCreateRoomDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Room'),
        content: TextField(
          controller: _roomNameController,
          decoration: const InputDecoration(
            hintText: 'Room name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _roomNameController.clear();
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final token = context.read<AuthProvider>().user?.token ?? '';
              final success = await context.read<RoomsProvider>().createRoom(
                token,
                _roomNameController.text.trim(),
              );

              if (success && mounted) {
                _roomNameController.clear();
                Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  // ─── Join Room Dialog ────────────────────────────────────────────────────
  // Shown when user taps a room they haven't joined yet
  void _showJoinRoomDialog(Room room) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Join "${room.name}"?'),
        content: Text('${room.memberCount} members already in this room.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final token = context.read<AuthProvider>().user?.token ?? '';
              final success = await context.read<RoomsProvider>().joinRoom(
                token,
                room.id,
              );

              if (mounted) {
                Navigator.pop(context);
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Joined "${room.name}"!')),
                  );
                }
              }
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }

  // ─── Rooms Tab ───────────────────────────────────────────────────────────
  // Builds the rooms list shown in the first tab
  Widget _buildRoomsTab() {
    final auth = context.watch<AuthProvider>();
    final rooms = context.watch<RoomsProvider>();

    if (rooms.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (rooms.rooms.isEmpty) {
      return const Center(
        child: Text(
          'No rooms yet.\nCreate one!',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () {
        final token = auth.user?.token ?? '';
        return rooms.fetchRooms(token);
      },
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: rooms.rooms.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final room = rooms.rooms[index];
          return Card(
            child: ListTile(
              // Room avatar with first letter of room name
              leading: CircleAvatar(
                backgroundColor: Colors.blue.shade100,
                child: Text(
                  room.name[0].toUpperCase(),
                  style: const TextStyle(color: Colors.blue),
                ),
              ),
              title: Text(
                room.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text('${room.memberCount} members'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () async {
                final token = auth.user?.token ?? '';
                final userId = auth.user?.id ?? 0;

                // Check if user is already a member of this room
                final isMember = await context
                    .read<RoomsProvider>()
                    .isRoomMember(token, room.id, userId);

                if (isMember && mounted) {
                  // Go directly to chat if already a member
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GroupChatScreen(room: room),
                    ),
                  );
                } else {
                  // Show join dialog if not a member
                  _showJoinRoomDialog(room);
                }
              },
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentIndex == 0 ? 'Chat Rooms' : 'Contacts'),
        actions: [
          // Show search and pending icons only on Contacts tab
          if (_currentIndex == 1) ...[
            IconButton(
              icon: Icon(_showSearch ? Icons.close : Icons.search),
              onPressed: () => setState(() => _showSearch = !_showSearch),
            ),
            IconButton(
              icon: const Icon(Icons.person_add),
              onPressed: () => Navigator.pushNamed(context, '/pending'),
            ),
          ],
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await context.read<AuthProvider>().logout();
              if (mounted) Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),

      // Switch between Rooms and Contacts tabs
      body: _currentIndex == 0
          ? _buildRoomsTab()
          : ContactsScreen(showSearch: _showSearch),

      // Bottom navigation bar with two tabs
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Rooms'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Contacts'),
        ],
      ),

      // Show FAB only on Rooms tab
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              onPressed: _showCreateRoomDialog,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
