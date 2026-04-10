const express = require('express');
const cors = require('cors');
require('dotenv').config();

require('./src/db/pool');

const authRoutes = require('./src/routes/auth');
const roomsRoutes = require('./src/routes/rooms');
const authMiddleware = require('./src/middleware/authMiddleware');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/rooms', roomsRoutes);

// Health check
app.get('/', (req, res) => {
  res.json({ message: 'Chat server is running!' });
});

// Protected test route
app.get('/api/protected', authMiddleware, (req, res) => {
  res.json({ message: `Hello ${req.user.username}, you are authenticated!` });
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});