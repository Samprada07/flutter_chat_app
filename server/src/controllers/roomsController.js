const pool = require('../db/pool');

// Create a room
const createRoom = async (req, res) => {
  const { name } = req.body;
  const userId = req.user.id;

  try {
    // Check if room already exists
    const existing = await pool.query(
      'SELECT * FROM rooms WHERE name = $1',
      [name]
    );

    if (existing.rows.length > 0) {
      return res.status(400).json({ error: 'Room already exists' });
    }

    // Create room
    const result = await pool.query(
      'INSERT INTO rooms (name, created_by) VALUES ($1, $2) RETURNING *',
      [name, userId]
    );

    const room = result.rows[0];

    // Auto-join creator to the room
    await pool.query(
      'INSERT INTO room_members (user_id, room_id) VALUES ($1, $2)',
      [userId, room.id]
    );

    res.status(201).json(room);

  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
};

// Get all rooms
const getRooms = async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT rooms.*, COUNT(room_members.user_id) AS member_count
       FROM rooms
       LEFT JOIN room_members ON rooms.id = room_members.room_id
       GROUP BY rooms.id
       ORDER BY rooms.created_at DESC`
    );

    res.json(result.rows);

  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
};

// Join a room
const joinRoom = async (req, res) => {
  const { roomId } = req.params;
  const userId = req.user.id;

  try {
    // Check if room exists
    const room = await pool.query(
      'SELECT * FROM rooms WHERE id = $1',
      [roomId]
    );

    if (room.rows.length === 0) {
      return res.status(404).json({ error: 'Room not found' });
    }

    // Check if already a member
    const existing = await pool.query(
      'SELECT * FROM room_members WHERE user_id = $1 AND room_id = $2',
      [userId, roomId]
    );

    if (existing.rows.length > 0) {
      return res.status(400).json({ error: 'Already a member' });
    }

    await pool.query(
      'INSERT INTO room_members (user_id, room_id) VALUES ($1, $2)',
      [userId, roomId]
    );

    res.json({ message: 'Joined room successfully' });

  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
};

// Get rooms for current user
const getMyRooms = async (req, res) => {
  const userId = req.user.id;

  try {
    const result = await pool.query(
      `SELECT rooms.*, COUNT(room_members.user_id) AS member_count
       FROM rooms
       JOIN room_members ON rooms.id = room_members.room_id
       WHERE rooms.id IN (
         SELECT room_id FROM room_members WHERE user_id = $1
       )
       GROUP BY rooms.id
       ORDER BY rooms.created_at DESC`,
      [userId]
    );

    res.json(result.rows);

  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
};

module.exports = { createRoom, getRooms, joinRoom, getMyRooms };