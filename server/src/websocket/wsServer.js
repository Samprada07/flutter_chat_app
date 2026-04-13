const WebSocket = require('ws');
const jwt = require('jsonwebtoken');
const pool = require('../db/pool');

// Store connected clients
// { roomId: [ { ws, userId, username } ] }
const rooms = {};

function setupWebSocket(server) {
  const wss = new WebSocket.Server({ server });

  wss.on('connection', (ws, req) => {
    console.log('New WebSocket connection');

    // Extract token from query string
    // ws://localhost:3000?token=xxx
    const params = new URLSearchParams(req.url.replace('/?', ''));
    const token = params.get('token');

    // Verify token
    let user;
    try {
      user = jwt.verify(token, process.env.JWT_SECRET);
      ws.user = user;
      console.log(`User connected: ${user.username}`);
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

          // Join a room
          case 'join_room':
            handleJoinRoom(ws, message.roomId);
            break;

          // Leave a room
          case 'leave_room':
            handleLeaveRoom(ws, message.roomId);
            break;

          // Send a message
          case 'send_message':
            await handleSendMessage(ws, message);
            break;

          default:
            console.log('Unknown message type:', message.type);
        }

      } catch (err) {
        console.error('Error handling message:', err);
      }
    });

    // Handle disconnect
    ws.on('close', () => {
      console.log(`User disconnected: ${ws.user?.username}`);
      removeFromAllRooms(ws);
    });

    // Handle errors
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

// Join a room
function handleJoinRoom(ws, roomId) {
  if (!rooms[roomId]) {
    rooms[roomId] = [];
  }

  // Avoid duplicate joins
  const alreadyIn = rooms[roomId].find(
    (client) => client.ws === ws
  );
  if (alreadyIn) return;

  rooms[roomId].push({ ws, userId: ws.user.id, username: ws.user.username });
  ws.currentRoom = roomId;

  console.log(`${ws.user.username} joined room ${roomId}`);

  // Notify room
  broadcastToRoom(roomId, {
    type: 'user_joined',
    username: ws.user.username,
    message: `${ws.user.username} joined the room`,
  }, ws);

  // Confirm to user
  ws.send(JSON.stringify({
    type: 'room_joined',
    roomId,
  }));
}

// Leave a room
function handleLeaveRoom(ws, roomId) {
  if (!rooms[roomId]) return;

  rooms[roomId] = rooms[roomId].filter(
    (client) => client.ws !== ws
  );

  console.log(`${ws.user.username} left room ${roomId}`);

  broadcastToRoom(roomId, {
    type: 'user_left',
    username: ws.user.username,
    message: `${ws.user.username} left the room`,
  });
}

// Send a message
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

// Broadcast to all clients in a room
function broadcastToRoom(roomId, message, excludeWs = null) {
  if (!rooms[roomId]) return;

  const data = JSON.stringify(message);

  rooms[roomId].forEach(({ ws }) => {
    if (ws !== excludeWs && ws.readyState === WebSocket.OPEN) {
      ws.send(data);
    }
  });
}

// Remove client from all rooms on disconnect
function removeFromAllRooms(ws) {
  Object.keys(rooms).forEach((roomId) => {
    rooms[roomId] = rooms[roomId].filter(
      (client) => client.ws !== ws
    );
  });
}

module.exports = { setupWebSocket };