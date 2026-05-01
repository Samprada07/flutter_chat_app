const express = require('express');
const http = require('http');
const cors = require('cors');
require('dotenv').config();

require('./src/db/pool');

const authRoutes = require('./src/routes/auth');
const roomsRoutes = require('./src/routes/rooms');
const contactsRoutes = require('./src/routes/contacts');
const directMessagesRoutes = require('./src/routes/directMessages');
const authMiddleware = require('./src/middleware/authMiddleware');
const { setupWebSocket } = require('./src/websocket/wsServer');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

// ─── Routes ───────────────────────────────────────────────────────────────
app.use('/api/auth', authRoutes);
app.use('/api/rooms', roomsRoutes);
app.use('/api/contacts', contactsRoutes);
app.use('/api/direct-messages', directMessagesRoutes);

// Health check
app.get('/', (req, res) => {
  res.json({ message: 'Chat server is running!' });
});

// Protected test route
app.get('/api/protected', authMiddleware, (req, res) => {
  res.json({ message: `Hello ${req.user.username}!` });
});

// ─── Global Error Handler ─────────────────────────────────────────────────
// Catches any unhandled errors thrown in route handlers
// Returns a clean error response instead of crashing the server
app.use((err, req, res, next) => {
  console.error('Unhandled error:', err.stack);
  res.status(500).json({
    error: 'Something went wrong. Please try again.',
  });
});

// ─── Handle 404 Routes ────────────────────────────────────────────────────
// Returns a clean error for any undefined routes
app.use((req, res) => {
  res.status(404).json({ error: 'Route not found' });
});

// ─── HTTP + WebSocket Server ──────────────────────────────────────────────
const server = http.createServer(app);
setupWebSocket(server);

server.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});