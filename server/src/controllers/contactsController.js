const pool = require('../db/pool');

// ─── Search Users ─────────────────────────────────────────────────────────
// Search for users by username so the current user can find
// and send them a contact request
const searchUsers = async (req, res) => {
  const { query } = req.query;
  const userId = req.user.id;

  try {
    // Find users whose username matches the search query
    // Exclude the current user from results
    const result = await pool.query(
      `SELECT id, username, email
       FROM users
       WHERE username ILIKE $1
       AND id != $2
       LIMIT 10`,
      [`%${query}%`, userId]
    );

    res.json(result.rows);

  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
};

// ─── Send Contact Request ─────────────────────────────────────────────────
// Sends a contact request from the current user to another user
// The request starts with status 'pending' until accepted
const sendContactRequest = async (req, res) => {
  const requesterId = req.user.id;
  const { receiverId } = req.body;

  try {
    // Prevent sending request to yourself
    if (requesterId === receiverId) {
      return res.status(400).json({ error: 'Cannot add yourself' });
    }

    // Check if a request already exists between these two users
    const existing = await pool.query(
      `SELECT * FROM contacts
       WHERE (requester_id = $1 AND receiver_id = $2)
       OR (requester_id = $2 AND receiver_id = $1)`,
      [requesterId, receiverId]
    );

    if (existing.rows.length > 0) {
      return res.status(400).json({ error: 'Contact request already exists' });
    }

    // Insert the contact request with pending status
    const result = await pool.query(
      `INSERT INTO contacts (requester_id, receiver_id, status)
       VALUES ($1, $2, 'pending')
       RETURNING *`,
      [requesterId, receiverId]
    );

    res.status(201).json(result.rows[0]);

  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
};

// ─── Accept Contact Request ───────────────────────────────────────────────
// Accepts a pending contact request
// Only the receiver of the request can accept it
const acceptContactRequest = async (req, res) => {
  const userId = req.user.id;
  const { contactId } = req.params;

  try {
    // Find the contact request and make sure current user is the receiver
    const contact = await pool.query(
      `SELECT * FROM contacts WHERE id = $1 AND receiver_id = $2`,
      [contactId, userId]
    );

    if (contact.rows.length === 0) {
      return res.status(404).json({ error: 'Contact request not found' });
    }

    // Update status from 'pending' to 'accepted'
    const result = await pool.query(
      `UPDATE contacts SET status = 'accepted'
       WHERE id = $1
       RETURNING *`,
      [contactId]
    );

    res.json(result.rows[0]);

  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
};

// ─── Get My Contacts ──────────────────────────────────────────────────────
// Returns all accepted contacts for the current user
// Includes the other user's details (username, email)
const getMyContacts = async (req, res) => {
  const userId = req.user.id;

  try {
    const result = await pool.query(
      `SELECT
         contacts.id AS contact_id,
         contacts.status,
         contacts.created_at,
         -- Get the other user's details (not the current user)
         CASE
           WHEN contacts.requester_id = $1 THEN receiver.id
           ELSE requester.id
         END AS user_id,
         CASE
           WHEN contacts.requester_id = $1 THEN receiver.username
           ELSE requester.username
         END AS username,
         CASE
           WHEN contacts.requester_id = $1 THEN receiver.email
           ELSE requester.email
         END AS email
       FROM contacts
       JOIN users AS requester ON contacts.requester_id = requester.id
       JOIN users AS receiver ON contacts.receiver_id = receiver.id
       WHERE (contacts.requester_id = $1 OR contacts.receiver_id = $1)
       AND contacts.status = 'accepted'
       ORDER BY contacts.created_at DESC`,
      [userId]
    );

    res.json(result.rows);

  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
};

// ─── Get Pending Requests ─────────────────────────────────────────────────
// Returns all pending contact requests received by the current user
// These are requests waiting to be accepted or rejected
const getPendingRequests = async (req, res) => {
  const userId = req.user.id;

  try {
    const result = await pool.query(
      `SELECT
         contacts.id AS contact_id,
         contacts.created_at,
         requester.id AS user_id,
         requester.username,
         requester.email
       FROM contacts
       JOIN users AS requester ON contacts.requester_id = requester.id
       WHERE contacts.receiver_id = $1
       AND contacts.status = 'pending'
       ORDER BY contacts.created_at DESC`,
      [userId]
    );

    res.json(result.rows);

  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
};

// ─── Remove Contact ───────────────────────────────────────────────────────
// Removes an accepted contact from the current user's contact list
const removeContact = async (req, res) => {
  const userId = req.user.id;
  const { contactId } = req.params;

  try {
    await pool.query(
      `DELETE FROM contacts
       WHERE id = $1
       AND (requester_id = $2 OR receiver_id = $2)`,
      [contactId, userId]
    );

    res.json({ message: 'Contact removed successfully' });

  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
};

module.exports = {
  searchUsers,
  sendContactRequest,
  acceptContactRequest,
  getMyContacts,
  getPendingRequests,
  removeContact,
};