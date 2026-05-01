// ─── Validate Register Input ──────────────────────────────────────────────
// Checks that all required fields are present and valid
// before passing the request to the auth controller
const validateRegister = (req, res, next) => {
  const { username, email, password } = req.body;

  // Check all fields are present
  if (!username || !email || !password) {
    return res.status(400).json({
      error: 'Username, email and password are required',
    });
  }

  // Username must be between 3 and 50 characters
  if (username.length < 3 || username.length > 50) {
    return res.status(400).json({
      error: 'Username must be between 3 and 50 characters',
    });
  }

  // Basic email format validation
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!emailRegex.test(email)) {
    return res.status(400).json({ error: 'Invalid email format' });
  }

  // Password must be at least 6 characters
  if (password.length < 6) {
    return res.status(400).json({
      error: 'Password must be at least 6 characters',
    });
  }

  next();
};

// ─── Validate Login Input ─────────────────────────────────────────────────
// Checks that email and password are present before
// passing the request to the auth controller
const validateLogin = (req, res, next) => {
  const { email, password } = req.body;

  if (!email || !password) {
    return res.status(400).json({
      error: 'Email and password are required',
    });
  }

  next();
};

// ─── Validate Room Input ──────────────────────────────────────────────────
// Checks that room name is present and valid
const validateRoom = (req, res, next) => {
  const { name } = req.body;

  if (!name) {
    return res.status(400).json({ error: 'Room name is required' });
  }

  // Room name must be between 3 and 100 characters
  if (name.length < 3 || name.length > 100) {
    return res.status(400).json({
      error: 'Room name must be between 3 and 100 characters',
    });
  }

  next();
};

// ─── Validate Direct Message Input ───────────────────────────────────────
// Checks that receiverId and content are present
const validateDirectMessage = (req, res, next) => {
  const { receiverId, content } = req.body;

  if (!receiverId) {
    return res.status(400).json({ error: 'Receiver ID is required' });
  }

  if (!content || content.trim().length === 0) {
    return res.status(400).json({ error: 'Message content is required' });
  }

  // Message content must not exceed 2000 characters
  if (content.length > 2000) {
    return res.status(400).json({
      error: 'Message too long. Max 2000 characters',
    });
  }

  next();
};

module.exports = {
  validateRegister,
  validateLogin,
  validateRoom,
  validateDirectMessage,
};