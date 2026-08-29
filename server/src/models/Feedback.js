const mongoose = require('mongoose');

const feedbackSchema = new mongoose.Schema({
  userId: {
    type: String,
    required: true,
  },
  userName: {
    type: String,
    required: true,
  },
  rating: {
    type: Number,
    required: true,
    min: 1,
    max: 5,
  },
  message: {
    type: String,
    default: '',
  },
  suggestions: {
    type: String,
    default: '',
  },
  platform: {
    type: String,
    default: 'unknown',
  },
}, {
  timestamps: true,
});

module.exports = mongoose.model('Feedback', feedbackSchema);
