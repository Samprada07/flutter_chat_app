const express = require('express');
const router = express.Router();
const { register, login } = require('../controllers/authControllers');
const {
  validateRegister,
  validateLogin,
} = require('../middleware/validateMiddleware');
const authMiddleware = require('../middleware/authMiddleware');
const pool = require('../db/pool');

// Get online status of a user
router.get('/status/:userId', authMiddleware, async (req, res) => {
  const { userId } = req.params;

  try {
    const result = await pool.query(
      `SELECT id, username, is_online, last_seen
       FROM users WHERE id = $1`,
      [userId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    res.json(result.rows[0]);

  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// Apply validation middleware before controller
router.post('/register', validateRegister, register);
router.post('/login', validateLogin, login);

module.exports = router;