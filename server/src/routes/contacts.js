const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/authMiddleware');
const {
  searchUsers,
  sendContactRequest,
  acceptContactRequest,
  getMyContacts,
  getPendingRequests,
  removeContact,
} = require('../controllers/contactsController');

// All routes are protected with JWT auth
router.use(authMiddleware);

router.get('/search', searchUsers);           // Search users by username
router.post('/request', sendContactRequest);  // Send contact request
router.put('/:contactId/accept', acceptContactRequest); // Accept request
router.get('/', getMyContacts);               // Get accepted contacts
router.get('/pending', getPendingRequests);   // Get pending requests
router.delete('/:contactId', removeContact);  // Remove a contact

module.exports = router;