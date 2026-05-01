const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/authMiddleware');
const { validateRoom } = require('../middleware/validateMiddleware');
const {
  createRoom,
  getRooms,
  joinRoom,
  getMyRooms,
  getRoomMessages,
} = require('../controllers/roomsController');

// All routes are protected
router.use(authMiddleware);

// Apply validateRoom before createRoom
router.post('/', validateRoom, createRoom);
router.get('/', getRooms);
router.get('/my', getMyRooms);
router.post('/:roomId/join', joinRoom);
router.get('/:roomId/messages', getRoomMessages);

module.exports = router;