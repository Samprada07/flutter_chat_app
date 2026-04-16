const pool = require('../db/pool');

// ─── Send Direct Message ──────────────────────────────────────────────────
// Sends a private message from the current user to another user
// Both users must be accepted contacts before messaging
const sendDirectMessage = async (req, res) => {
  const senderId = req.user.id;
  const { receiverId, content } = req.body;

  try {
    // Verify that both users are accepted contacts
    const contact = await pool.query(
      `SELECT * FROM contacts
       WHERE (requester_id = $1 AND receiver_id = $2)
       OR (requester_id = $2 AND receiver_id = $1)
       AND status = 'accepted'`,
      [senderId, receiverId]
    );

    if (contact.rows.length === 0) {
      return res.status(403).json({ error: 'You are not contacts' });
    }

    // Insert the message into direct_messages table
    const result = await pool.query(
      `INSERT INTO direct_messages (sender_id, receiver_id, content)
       VALUES ($1, $2, $3)
       RETURNING *`,
      [senderId, receiverId, content]
    );

    res.status(201).json(result.rows[0]);

  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
};

// ─── Get Conversation ─────────────────────────────────────────────────────
// Returns full message history between the current user and another user
// Messages are ordered oldest first (like WhatsApp)
const getConversation = async (req, res) => {
  const userId = req.user.id;
  const { contactId } = req.params;

  try {
    const result = await pool.query(
      `SELECT
         direct_messages.*,
         sender.username AS sender_name
       FROM direct_messages
       JOIN users AS sender ON direct_messages.sender_id = sender.id
       WHERE (sender_id = $1 AND receiver_id = $2)
       OR (sender_id = $2 AND receiver_id = $1)
       ORDER BY created_at ASC`,
      [userId, contactId]
    );

    // Mark all received messages as read
    await pool.query(
      `UPDATE direct_messages SET is_read = TRUE
       WHERE receiver_id = $1 AND sender_id = $2`,
      [userId, contactId]
    );

    res.json(result.rows);

  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
};

// ─── Get All Conversations ────────────────────────────────────────────────
// Returns a summary of all conversations for the current user
// Shows the last message and unread count for each contact
// This is what populates the Chats tab on the home screen
const getConversations = async (req, res) => {
  const userId = req.user.id;

  try {
    const result = await pool.query(
      `SELECT DISTINCT ON (other_user.id)
         other_user.id AS user_id,
         other_user.username,
         direct_messages.content AS last_message,
         direct_messages.created_at AS last_message_at,
         -- Count unread messages from this contact
         COUNT(CASE WHEN direct_messages.is_read = FALSE
               AND direct_messages.receiver_id = $1
               THEN 1 END) AS unread_count
       FROM direct_messages
       JOIN users AS other_user ON
         CASE
           WHEN direct_messages.sender_id = $1 THEN direct_messages.receiver_id
           ELSE direct_messages.sender_id
         END = other_user.id
       WHERE direct_messages.sender_id = $1
       OR direct_messages.receiver_id = $1
       GROUP BY other_user.id, other_user.username,
                direct_messages.content, direct_messages.created_at
       ORDER BY other_user.id, direct_messages.created_at DESC`,
      [userId]
    );

    res.json(result.rows);

  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
};

module.exports = {
  sendDirectMessage,
  getConversation,
  getConversations,
};