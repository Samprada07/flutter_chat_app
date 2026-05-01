const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/authMiddleware');
const { validateDirectMessage } = require('../middleware/validateMiddleware');
const {
  sendDirectMessage,
  getConversation,
  getConversations,
} = require('../controllers/directMessagesController');

router.use(authMiddleware);

// Apply validateDirectMessage before sendDirectMessage
router.post('/', validateDirectMessage, sendDirectMessage);
router.get('/', getConversations);
router.get('/:contactId', getConversation);

module.exports = router;