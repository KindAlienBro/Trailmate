const jwt = require('jsonwebtoken');

/**
 * JWT Authentication Middleware — Single-Login Architecture
 *
 * TrailMate AI uses a single login: the FastAPI backend issues the JWT,
 * and this Node.js group server validates the SAME token using the
 * shared JWT_SECRET. No MongoDB User lookup is needed for authentication.
 *
 * The JWT payload is expected to contain:
 *   - userId (string): user's UUID from PostgreSQL
 *   - name   (string): user's display name
 *   - email  (string): user's email
 */
const authenticate = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'No token provided' });
    }

    const token = authHeader.split(' ')[1];
    const decoded = jwt.verify(token, process.env.JWT_SECRET);

    // Use payload directly — no MongoDB user lookup
    req.user = {
      id: decoded.userId || decoded.sub,
      name: decoded.name || decoded.username || 'Unknown',
      email: decoded.email || '',
    };
    req.userId = req.user.id;

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
 * Verifies JWT from socket handshake auth using the same JWT_SECRET.
 */
const authenticateSocket = async (socket, next) => {
  try {
    const token = socket.handshake.auth?.token;
    if (!token) {
      return next(new Error('Authentication token required'));
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET);

    socket.user = {
      id: decoded.userId || decoded.sub,
      name: decoded.name || decoded.username || 'Unknown',
      email: decoded.email || '',
    };
    socket.userId = socket.user.id;

    next();
  } catch (error) {
    next(new Error('Authentication failed'));
  }
};

module.exports = { authenticate, authenticateSocket };
