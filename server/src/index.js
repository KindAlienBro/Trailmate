require('dotenv').config();

const express = require('express');
const http = require('http');
const cors = require('cors');
const mongoose = require('mongoose');
const { Server } = require('socket.io');

const authRoutes = require('./routes/auth');
const groupRoutes = require('./routes/groups');
const olaProxyRoutes = require('./routes/olaProxy');
const { authenticateSocket } = require('./middleware/auth');
const { setupLocationHub } = require('./sockets/locationHub');
const { setupAlertEngine } = require('./sockets/alertEngine');
const { setupRouteSync } = require('./sockets/routeSync');

const app = express();
const server = http.createServer(app);

// ==================== Middleware ====================
app.use(cors({
  origin: '*', // In production, restrict this to your Flutter app's domain
  methods: ['GET', 'POST', 'PUT', 'DELETE'],
}));
app.use(express.json());

// ==================== REST Routes ====================
app.get('/api/health', (req, res) => {
  res.json({
    status: 'ok',
    service: 'TrailMate Server',
    timestamp: new Date().toISOString(),
  });
});

app.use('/api/auth', authRoutes);
app.use('/api/groups', groupRoutes);
app.use('/api/maps', olaProxyRoutes);

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

// Make io accessible from routes if needed
app.set('io', io);

// ==================== MongoDB Connection ====================
const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017/trailmate';
const PORT = process.env.PORT || 3000;

mongoose.connect(MONGODB_URI)
  .then(() => {
    console.log('✅ Connected to MongoDB');

    server.listen(PORT, () => {
      console.log(`\n🚀 TrailMate Server running on port ${PORT}`);
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
