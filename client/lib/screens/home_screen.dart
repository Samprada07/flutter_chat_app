import 'package:chat_app/screens/group_chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/rooms_provider.dart';
import '../models/room.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _roomNameController = TextEditingController();

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

  // Create room dialog
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

  // Join room dialog
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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final rooms = context.watch<RoomsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat Rooms'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await auth.logout();
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),

      body: rooms.isLoading
          ? const Center(child: CircularProgressIndicator())
          : rooms.rooms.isEmpty
          ? const Center(
              child: Text(
                'No rooms yet.\nCreate one!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            )
          : RefreshIndicator(
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
                        final token =
                            context.read<AuthProvider>().user?.token ?? '';
                        final userId =
                            context.read<AuthProvider>().user?.id ?? 0;

                        // If user is already a member, go directly to chat
                        // Otherwise show join dialog first
                        final isMember = await context
                            .read<RoomsProvider>()
                            .isRoomMember(token, room.id, userId);

                        if (isMember && mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => GroupChatScreen(room: room),
                            ),
                          );
                        } else {
                          _showJoinRoomDialog(room);
                        }
                      },
                    ),
                  );
                },
              ),
            ),

      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateRoomDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
