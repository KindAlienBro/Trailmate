const express = require('express');
const router = express.Router();
const Feedback = require('../models/Feedback');

// POST /api/feedback
router.post('/', async (req, res) => {
  try {
    const { userId, userName, rating, message, suggestions, platform } = req.body;

    const newFeedback = new Feedback({
      userId,
      userName,
      rating,
      message,
      suggestions,
      platform,
    });

    await newFeedback.save();

    res.status(201).json({ success: true, message: 'Feedback submitted successfully' });
  } catch (error) {
    console.error('Error submitting feedback:', error);
    res.status(500).json({ success: false, error: 'Failed to submit feedback' });
  }
});

module.exports = router;
