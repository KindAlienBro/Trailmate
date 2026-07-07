const express = require('express');
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const { authenticate } = require('../middleware/auth');

const router = express.Router();

/**
 * POST /api/auth/register
 * Create a new user account
 */
router.post('/register', async (req, res) => {
  try {
    const { name, email, password } = req.body;

    if (!name || !email || !password) {
      return res.status(400).json({ error: 'Name, email, and password are required' });
    }

    if (password.length < 6) {
      return res.status(400).json({ error: 'Password must be at least 6 characters' });
    }

    // Check if user already exists
    const existingUser = await User.findOne({ email: email.toLowerCase() });
    if (existingUser) {
      return res.status(409).json({ error: 'Email already registered' });
    }

    // Create user (password is hashed in pre-save hook)
    const user = new User({
      name: name.trim(),
      email: email.toLowerCase().trim(),
      passwordHash: password,
    });
    await user.save();

    // Generate JWT token
    const token = jwt.sign(
      { userId: user._id },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
    );

    res.status(201).json({
      message: 'Account created successfully',
      token,
      user: user.toJSON(),
    });
  } catch (error) {
    console.error('Register error:', error);
    res.status(500).json({ error: 'Server error during registration' });
  }
});

/**
 * POST /api/auth/login
 * Login with email and password
 */
router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ error: 'Email and password are required' });
    }

    // Find user by email
    const user = await User.findOne({ email: email.toLowerCase().trim() });
    if (!user) {
      return res.status(401).json({ error: 'Invalid email or password' });
    }

    // Compare password
    const isMatch = await user.comparePassword(password);
    if (!isMatch) {
      return res.status(401).json({ error: 'Invalid email or password' });
    }

    // Generate JWT token
    const token = jwt.sign(
      { userId: user._id },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
    );

    res.json({
      message: 'Login successful',
      token,
      user: user.toJSON(),
    });
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ error: 'Server error during login' });
  }
});

/**
 * GET /api/auth/me
 * Get current user profile (requires auth)
 */
router.get('/me', authenticate, async (req, res) => {
  try {
    res.json({ user: req.user.toJSON() });
  } catch (error) {
    console.error('Get profile error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

/**
 * PUT /api/auth/me
 * Update current user profile
 */
router.put('/me', authenticate, async (req, res) => {
  try {
    const { name, phone, avatar } = req.body;
    const user = await User.findById(req.userId);

    if (name) user.name = name.trim();
    if (phone) user.phone = phone;
    if (avatar) user.avatar = avatar;

    await user.save();
    res.json({ user: user.toJSON() });
  } catch (error) {
    console.error('Update profile error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
