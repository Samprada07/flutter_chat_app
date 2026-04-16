const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/authMiddleware');
const {
  sendDirectMessage,
  getConversation,
  getConversations,
} = require('../controllers/directMessagesController');

// All routes are protected with JWT auth
router.use(authMiddleware);

router.post('/', sendDirectMessage);                // Send a direct message
router.get('/', getConversations);                  // Get all conversations
router.get('/:contactId', getConversation);         // Get single conversation

module.exports = router;