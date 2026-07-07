const jwt = require('jsonwebtoken');
const User = require('../models/User');

/**
 * JWT Authentication Middleware
 * Extracts and verifies JWT token from Authorization header.
 * Attaches the user object to req.user on success.
 */
const authenticate = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'No token provided' });
    }

    const token = authHeader.split(' ')[1];
    const decoded = jwt.verify(token, process.env.JWT_SECRET);

    const user = await User.findById(decoded.userId).select('-passwordHash');
    if (!user) {
      return res.status(401).json({ error: 'User not found' });
    }

    req.user = user;
    req.userId = user._id.toString();
    next();
  } catch (error) {
    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({ error: 'Token expired' });
    }
    return res.status(401).json({ error: 'Invalid token' });
  }
};

/**
 * Socket.IO Authentication Middleware
 * Verifies JWT from socket handshake auth.
 */
const authenticateSocket = async (socket, next) => {
  try {
    const token = socket.handshake.auth?.token;
    if (!token) {
      return next(new Error('Authentication token required'));
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    const user = await User.findById(decoded.userId).select('-passwordHash');
    if (!user) {
      return next(new Error('User not found'));
    }

    socket.user = user;
    socket.userId = user._id.toString();
    next();
  } catch (error) {
    next(new Error('Authentication failed'));
  }
};

module.exports = { authenticate, authenticateSocket };
