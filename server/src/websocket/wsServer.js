const WebSocket = require('ws');
const jwt = require('jsonwebtoken');
const pool = require('../db/pool');

// Store connected clients
const rooms = {};
let wss;

function setupWebSocket(server) {
  wss = new WebSocket.Server({ server });

  wss.on('connection', async (ws, req) => {
    console.log('New WebSocket connection');

    // Extract token from query string
    const params = new URLSearchParams(req.url.replace('/?', ''));
    const token = params.get('token');

    // Verify token
    let user;
    try {
      user = jwt.verify(token, process.env.JWT_SECRET);
      ws.user = user;
      console.log(`User connected: ${user.username}`);

      // Mark user as online in database
      await setUserOnline(user.id, true);

      // Broadcast to all connected clients that this user is online
      broadcastPresence(user.id, true);

    } catch (err) {
      console.log('Invalid token, closing connection');
      ws.close();
      return;
    }

    // Handle incoming messages
    ws.on('message', async (data) => {
      try {
        const message = JSON.parse(data);

        switch (message.type) {
          case 'join_room':
            handleJoinRoom(ws, message.roomId);
            break;
          case 'leave_room':
            handleLeaveRoom(ws, message.roomId);
            break;
          case 'send_message':
            await handleSendMessage(ws, message);
            break;
          case 'send_direct_message':
            await handleSendDirectMessage(ws, message);
            break;
          default:
            console.log('Unknown message type:', message.type);
        }

      } catch (err) {
        console.error('Error handling message:', err);
      }
    });

    // Handle disconnect — mark user as offline
    ws.on('close', async () => {
      console.log(`User disconnected: ${ws.user?.username}`);
      removeFromAllRooms(ws);

      if (ws.user) {
        // Mark user as offline and update last seen
        await setUserOnline(ws.user.id, false);

        // Broadcast to all connected clients that this user is offline
        broadcastPresence(ws.user.id, false);
      }
    });

    ws.on('error', (err) => {
      console.error('WebSocket error:', err);
    });

    // Send connection success
    ws.send(JSON.stringify({
      type: 'connected',
      message: `Welcome ${user.username}!`,
    }));
  });

  console.log('WebSocket server is ready');
  return wss;
}

// ─── Set User Online/Offline ──────────────────────────────────────────────
// Updates the user's online status and last_seen in the database
async function setUserOnline(userId, isOnline) {
  try {
    await pool.query(
      `UPDATE users
       SET is_online = $1, last_seen = NOW()
       WHERE id = $2`,
      [isOnline, userId]
    );
  } catch (err) {
    console.error('Error updating online status:', err);
  }
}

// ─── Broadcast Presence ───────────────────────────────────────────────────
// Notifies all connected clients when a user comes online or goes offline
// This allows the UI to update the online indicator in real-time
function broadcastPresence(userId, isOnline) {
  const payload = JSON.stringify({
    type: 'presence_update',
    userId,
    isOnline,
    lastSeen: new Date().toIso8601String,
  });

  // Send to all connected clients
  wss.clients.forEach((client) => {
    if (client.readyState === WebSocket.OPEN) {
      client.send(JSON.stringify({
        type: 'presence_update',
        userId,
        isOnline,
        lastSeen: new Date().toISOString(),
      }));
    }
  });
}

// ─── Join Room ────────────────────────────────────────────────────────────
function handleJoinRoom(ws, roomId) {
  if (!rooms[roomId]) rooms[roomId] = [];

  // Avoid duplicate joins
  const alreadyIn = rooms[roomId].find((client) => client.ws === ws);
  if (alreadyIn) return;

  rooms[roomId].push({
    ws,
    userId: ws.user.id,
    username: ws.user.username,
  });
  ws.currentRoom = roomId;

  console.log(`${ws.user.username} joined room ${roomId}`);

  broadcastToRoom(roomId, {
    type: 'user_joined',
    username: ws.user.username,
    message: `${ws.user.username} joined the room`,
  }, ws);

  ws.send(JSON.stringify({ type: 'room_joined', roomId }));
}

// ─── Leave Room ───────────────────────────────────────────────────────────
function handleLeaveRoom(ws, roomId) {
  if (!rooms[roomId]) return;

  rooms[roomId] = rooms[roomId].filter((client) => client.ws !== ws);

  console.log(`${ws.user.username} left room ${roomId}`);

  broadcastToRoom(roomId, {
    type: 'user_left',
    username: ws.user.username,
    message: `${ws.user.username} left the room`,
  });
}

// ─── Send Room Message ────────────────────────────────────────────────────
async function handleSendMessage(ws, message) {
  const { roomId, content } = message;
  if (!content || !roomId) return;

  try {
    // Save message to PostgreSQL
    const result = await pool.query(
      `INSERT INTO messages (room_id, sender_id, content)
       VALUES ($1, $2, $3)
       RETURNING id, room_id, sender_id, content, created_at`,
      [roomId, ws.user.id, content]
    );

    const savedMessage = result.rows[0];

    // Broadcast to everyone in the room including sender
    broadcastToRoom(roomId, {
      type: 'new_message',
      id: savedMessage.id,
      roomId: savedMessage.room_id,
      senderId: savedMessage.sender_id,
      senderName: ws.user.username,
      content: savedMessage.content,
      createdAt: savedMessage.created_at,
    });

  } catch (err) {
    console.error('Error saving message:', err);
    ws.send(JSON.stringify({
      type: 'error',
      message: 'Failed to send message',
    }));
  }
}

// ─── Send Direct Message ──────────────────────────────────────────────────
// Saves the direct message to PostgreSQL and delivers it
// to the receiver if they are currently connected
async function handleSendDirectMessage(ws, message) {
  const { receiverId, content } = message;

  if (!receiverId || !content) return;

  try {
    const result = await pool.query(
      `INSERT INTO direct_messages (sender_id, receiver_id, content)
       VALUES ($1, $2, $3)
       RETURNING id, sender_id, receiver_id, content, created_at`,
      [ws.user.id, receiverId, content]
    );

    const savedMessage = result.rows[0];

    // Build the message payload to send to receiver
    const payload = JSON.stringify({
      type: 'new_direct_message',
      id: savedMessage.id,
      senderId: savedMessage.sender_id,
      senderName: ws.user.username,
      receiverId: savedMessage.receiver_id,
      content: savedMessage.content,
      createdAt: savedMessage.created_at,
    });

    // Deliver to receiver if online
    wss.clients.forEach((client) => {
      if (
        client.user?.id === parseInt(receiverId) &&
        client.readyState === WebSocket.OPEN
      ) {
        client.send(payload);
      }
    });

  } catch (err) {
    console.error('Error sending direct message:', err);
    ws.send(JSON.stringify({
      type: 'error',
      message: 'Failed to send direct message',
    }));
  }
}

// ─── Broadcast to Room ────────────────────────────────────────────────────
function broadcastToRoom(roomId, message, excludeWs = null) {
  if (!rooms[roomId]) return;

  const data = JSON.stringify(message);

  rooms[roomId].forEach(({ ws }) => {
    if (ws !== excludeWs && ws.readyState === WebSocket.OPEN) {
      ws.send(data);
    }
  });
}

// ─── Remove from All Rooms ────────────────────────────────────────────────
function removeFromAllRooms(ws) {
  Object.keys(rooms).forEach((roomId) => {
    rooms[roomId] = rooms[roomId].filter(
      (client) => client.ws !== ws
    );
  });
}

module.exports = { setupWebSocket };