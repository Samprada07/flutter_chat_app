import 'package:flutter/material.dart';
import '../services/ws_service.dart';

// ─── Connection Banner ────────────────────────────────────────────────────
// Shows a red banner at the top when WebSocket is disconnected
// Automatically hides when connection is restored
class ConnectionBanner extends StatelessWidget {
  const ConnectionBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final isConnected = WsService().isConnected;

    // Don't show anything when connected
    if (isConnected) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: Colors.red,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Text(
            'Reconnecting...',
            style: TextStyle(color: Colors.white, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
