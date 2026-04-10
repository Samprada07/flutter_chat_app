const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/authMiddleware');
const {
  createRoom,
  getRooms,
  joinRoom,
  getMyRooms,
} = require('../controllers/roomsController');

// All routes are protected
router.use(authMiddleware);

router.post('/', createRoom);
router.get('/', getRooms);
router.get('/my', getMyRooms);
router.post('/:roomId/join', joinRoom);

module.exports = router;