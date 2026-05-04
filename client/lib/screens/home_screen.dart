import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/rooms_provider.dart';
import '../providers/direct_messages_provider.dart';
import '../models/room.dart';
import 'group_chat_screen.dart';
import 'contacts_screen.dart';
import 'chats_screen.dart';
import '../widgets/empty_state.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _roomNameController = TextEditingController();

  // 0 = Rooms, 1 = Chats, 2 = Contacts
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

  // ─── Join Room Dialog ────────────────────────────────────────────────────
  // Shown when user taps a room they haven't joined yet
  Widget _buildRoomsTab() {
    final auth = context.watch<AuthProvider>();
    final rooms = context.watch<RoomsProvider>();

    if (rooms.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (rooms.rooms.isEmpty) {
      return const EmptyState(
        icon: Icons.chat_bubble_outline,
        title: 'No rooms yet',
        subtitle: 'Tap + to create a new room',
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
        separatorBuilder: (_, _) => const SizedBox(height: 8),
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

  // ─── Chats Icon with Unread Badge ─────────────────────────────────────────
  // Builds the Chats tab icon with a red badge showing
  // the number of conversations with unread messages
  Widget _buildChatsIcon(BuildContext context, {bool isActive = false}) {
    // Watch DirectMessagesProvider for unread count changes
    final totalUnread = context
        .watch<DirectMessagesProvider>()
        .totalUnreadCount;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Base icon
        Icon(isActive ? Icons.message : Icons.message_outlined),

        // Show badge only if there are unread conversations
        if (totalUnread > 0)
          Positioned(
            right: -6,
            top: -4,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                // Show 9+ if more than 9 unread conversations
                totalUnread > 9 ? '9+' : '$totalUnread',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  // ─── App Bar Title ────────────────────────────────────────────────────────
  // Returns the correct title based on the active tab
  String get _appBarTitle {
    switch (_currentIndex) {
      case 0:
        return 'Rooms';
      case 1:
        return 'Chats';
      case 2:
        return 'Contacts';
      default:
        return 'Chat App';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_appBarTitle),
        actions: [
          // Show search and pending icons only on Contacts tab
          if (_currentIndex == 2) ...[
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
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),

      // Switch between tabs
      body: IndexedStack(
        index: _currentIndex,
        children: [
          // Tab 0: Rooms
          _buildRoomsTab(),
          // Tab 1: Chats
          const ChatsScreen(),
          // Tab 2: Contacts
          ContactsScreen(showSearch: _showSearch),
        ],
      ),

      // Bottom navigation with 3 tabs
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() {
          _currentIndex = index;
          if (index != 2) _showSearch = false;
        }),
        items: [
          // Rooms tab
          const BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: 'Rooms',
          ),

          // Chats tab with unread badge
          BottomNavigationBarItem(
            icon: _buildChatsIcon(context),
            activeIcon: _buildChatsIcon(context, isActive: true),
            label: 'Chats',
          ),

          // Contacts tab
          const BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: 'Contacts',
          ),
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
