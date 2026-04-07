const express = require('express');
const cors = require('cors');
require('dotenv').config();

require('./src/db/pool');

const authRoutes = require('./src/routes/auth');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

// Routes
app.use('/api/auth', authRoutes);

// Health check
app.get('/', (req, res) => {
  res.json({ message: 'Chat server is running!' });
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});