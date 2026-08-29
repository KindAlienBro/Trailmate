require('dotenv').config();

const express = require('express');
const http = require('http');
const cors = require('cors');
const mongoose = require('mongoose');
const { Server } = require('socket.io');

const authRoutes = require('./routes/auth');
const groupRoutes = require('./routes/groups');
const olaProxyRoutes = require('./routes/olaProxy');
const smartRouteRoutes = require('./routes/smartRoute');
const feedbackRoutes = require('./routes/feedback');
const privacyRoutes = require('./routes/privacy');
const { authenticateSocket } = require('./middleware/auth');
const { setupLocationHub } = require('./sockets/locationHub');
const { setupAlertEngine } = require('./sockets/alertEngine');
const { setupRouteSync } = require('./sockets/routeSync');
const { setupSmartSuggestions } = require('./sockets/smartSuggestions');

const app = express();
const server = http.createServer(app);

// ==================== Middleware ====================
app.use(cors({
  origin: '*', // In production, restrict this to your Flutter app's domain
  methods: ['GET', 'POST', 'PUT', 'DELETE'],
}));
app.use(express.json({ limit: '50mb' }));

// ==================== REST Routes ====================
app.get('/api/health', (req, res) => {
  res.json({
    status: 'ok',
    service: 'RoUniity Server',
    timestamp: new Date().toISOString(),
  });
});

app.get('/ping', (req, res) => {
  res.send('pong');
});

app.use('/api/auth', authRoutes);
app.use('/api/groups', groupRoutes);
app.use('/api/maps', olaProxyRoutes);
app.use('/api/maps', smartRouteRoutes);
app.use('/api/feedback', feedbackRoutes);
app.use('/privacy', privacyRoutes);

// Global Error Handler to always return JSON (catches PayloadTooLarge, SyntaxError, etc)
app.use((err, req, res, next) => {
  console.error('Express Global Error:', err.message);
  res.status(err.status || 500).json({ error: err.message || 'Internal Server Error' });
});

// ==================== Socket.IO Setup ====================
const io = new Server(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST'],
  },
  pingTimeout: 60000,
  pingInterval: 25000,
});

// Socket.IO authentication middleware
io.use(authenticateSocket);

// Register WebSocket handlers
setupLocationHub(io);
setupAlertEngine(io);
setupRouteSync(io);
setupSmartSuggestions(io);

// Make io accessible from routes if needed
app.set('io', io);

// ==================== MongoDB Connection ====================
const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017/rouniity';
const PORT = process.env.PORT || 3000;

mongoose.connect(MONGODB_URI)
  .then(() => {
    console.log('✅ Connected to MongoDB');

    server.listen(PORT, '0.0.0.0', () => {
      console.log(`\n🚀 RoUniity Server running on port ${PORT}`);
      console.log(`   REST API:  http://localhost:${PORT}/api`);
      console.log(`   WebSocket: ws://localhost:${PORT}`);
      console.log(`   Health:    http://localhost:${PORT}/api/health\n`);
    });
  })
  .catch((err) => {
    console.error('❌ MongoDB connection error:', err.message);
    console.error('   Make sure MongoDB is running on your machine.');
    process.exit(1);
  });

// ==================== Graceful Shutdown ====================
process.on('SIGINT', async () => {
  console.log('\n🛑 Shutting down...');
  await mongoose.connection.close();
  server.close();
  process.exit(0);
});
