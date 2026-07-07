const mongoose = require('mongoose');

const memberSchema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  name: { type: String, required: true },
  avatar: { type: String, default: null },
  role: { type: String, enum: ['leader', 'member'], default: 'member' },
  joinedAt: { type: Date, default: Date.now },
  // Live location data (updated via WebSocket, stored for reconnection)
  lastLocation: {
    lat: { type: Number, default: null },
    lng: { type: Number, default: null },
    speed: { type: Number, default: 0 },       // km/h
    heading: { type: Number, default: 0 },      // degrees
    updatedAt: { type: Date, default: null },
  },
  status: {
    type: String,
    enum: ['waiting', 'on-route', 'deviated', 'stopped', 'sos'],
    default: 'waiting',
  },
  lastSeparationAlertAt: { type: Date, default: null },
});

const waypointSchema = new mongoose.Schema({
  lat: { type: Number, required: true },
  lng: { type: Number, required: true },
  name: { type: String, default: '' },
  address: { type: String, default: '' },
  order: { type: Number, required: true },
});

const groupSchema = new mongoose.Schema({
  name: {
    type: String,
    required: true,
    trim: true,
    minlength: 2,
    maxlength: 100,
  },
  inviteCode: {
    type: String,
    required: true,
    unique: true,
    uppercase: true,
    length: 6,
  },
  leaderId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },
  members: [memberSchema],
  route: {
    transportMode: { type: String, enum: ['driving', 'two_wheeler', 'walking', 'bicycling'], default: 'driving' },
    origin: {
      lat: { type: Number, default: null },
      lng: { type: Number, default: null },
      name: { type: String, default: '' },
      address: { type: String, default: '' },
    },
    destination: {
      lat: { type: Number, default: null },
      lng: { type: Number, default: null },
      name: { type: String, default: '' },
      address: { type: String, default: '' },
    },
    waypoints: [waypointSchema],
    // Encoded polyline from Ola Directions API
    polyline: { type: String, default: null },
    // Decoded polyline points for deviation checking
    polylinePoints: [{
      lat: Number,
      lng: Number,
    }],
    distanceMeters: { type: Number, default: 0 },
    durationSeconds: { type: Number, default: 0 },
  },
  status: {
    type: String,
    enum: ['planning', 'active', 'paused', 'completed'],
    default: 'planning',
  },
  maxMembers: {
    type: Number,
    default: 20,
  },
  settings: {
    deviationThresholdMeters: { type: Number, default: 500 },
    separationThresholdMeters: { type: Number, default: 2000 },
    stallTimeoutMinutes: { type: Number, default: 10 },
    locationUpdateIntervalSeconds: { type: Number, default: 5 },
  },
}, {
  timestamps: true,
});

// Index for fast lookups
groupSchema.index({ leaderId: 1 });
groupSchema.index({ 'members.userId': 1 });

// Check if a user is a member of this group
groupSchema.methods.isMember = function (userId) {
  return this.members.some(m => m.userId.toString() === userId.toString());
};

// Check if a user is the leader
groupSchema.methods.isLeader = function (userId) {
  return this.leaderId.toString() === userId.toString();
};

// Get member by userId
groupSchema.methods.getMember = function (userId) {
  return this.members.find(m => m.userId.toString() === userId.toString());
};

module.exports = mongoose.model('Group', groupSchema);
