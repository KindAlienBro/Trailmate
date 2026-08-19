const express = require('express');
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const Otp = require('../models/Otp');
const { authenticate } = require('../middleware/auth');

const router = express.Router();

/**
 * Helper to generate a 6-digit OTP
 */
function generateOTP() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

/**
 * POST /api/auth/send-otp
 * Send an OTP to a phone number (Mock implementation)
 */
router.post('/send-otp', async (req, res) => {
  try {
    const { phone } = req.body;
    
    if (!phone) {
      return res.status(400).json({ error: 'Phone number is required' });
    }

    const otpCode = generateOTP();

    // In a real app, integrate Twilio/Firebase Auth/AWS SNS here.
    console.log(`\n\n[MOCK SMS] OTP for ${phone} is: ${otpCode}\n\n`);

    // Remove existing OTPs for this phone to prevent spam issues
    await Otp.deleteMany({ phone });

    const newOtp = new Otp({
      phone,
      otp: otpCode,
    });
    
    await newOtp.save();

    res.json({ message: 'OTP sent successfully' });
  } catch (error) {
    console.error('Send OTP error:', error);
    res.status(500).json({ error: 'Server error while sending OTP' });
  }
});

/**
 * POST /api/auth/register
 * Register with name, email, phone, password, and OTP
 */
router.post('/register', async (req, res) => {
  try {
    const { name, email, phone, password } = req.body;

    if (!name || !email || !phone || !password) {
      return res.status(400).json({ error: 'All fields (name, email, phone, password) are required' });
    }

    if (password.length < 6) {
      return res.status(400).json({ error: 'Password must be at least 6 characters' });
    }

    // Check if user already exists with this email or phone
    const existingUser = await User.findOne({
      $or: [
        { email: email.toLowerCase() },
        { phone: phone }
      ]
    });

    if (existingUser) {
      return res.status(409).json({ error: 'Email or phone number already registered' });
    }

    // NOTE: OTP is currently verified on the frontend via Firebase Auth.
    // In a production environment, you would receive the Firebase ID Token here and verify it using firebase-admin.
    // For now, we trust the frontend verification.

    // Create user (password is hashed in pre-save hook)
    const user = new User({
      name: name.trim(),
      email: email.toLowerCase().trim(),
      phone: phone.trim(),
      passwordHash: password,
    });
    await user.save();

    // Cleanup mock OTPs if any
    await Otp.deleteMany({ phone });

    // Generate JWT token
    const token = jwt.sign(
      { userId: user._id },
      process.env.JWT_SECRET || 'secret',
      { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
    );

    res.status(201).json({
      message: 'Account created successfully',
      token,
      user: safeUserJSON(user),
    });
  } catch (error) {
    console.error('Register error:', error);
    res.status(500).json({ error: 'Server error during registration' });
  }
});

/**
 * POST /api/auth/login
 * Login with email or phone and password
 */
router.post('/login', async (req, res) => {
  try {
    const { identifier, password } = req.body; // identifier can be email or phone

    if (!identifier || !password) {
      return res.status(400).json({ error: 'Email/Phone and password are required' });
    }

    const searchIdentifier = identifier.trim().toLowerCase();

    // Find user by email or phone
    const user = await User.findOne({
      $or: [
        { email: searchIdentifier },
        { phone: identifier.trim() }
      ]
    });

    if (!user) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    // Compare password
    const isMatch = await user.comparePassword(password);
    if (!isMatch) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    // Generate JWT token
    const token = jwt.sign(
      { userId: user._id },
      process.env.JWT_SECRET || 'secret',
      { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
    );

    res.json({
      message: 'Login successful',
      token,
      user: safeUserJSON(user),
    });
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ error: 'Server error during login' });
  }
});

function safeUserJSON(user) {
  if (!user) return null;
  if (typeof user.toJSON === 'function') return user.toJSON();
  if (typeof user.toObject === 'function') {
    const obj = user.toObject();
    delete obj.passwordHash;
    return obj;
  }
  const obj = user._doc ? { ...user._doc } : { ...user };
  delete obj.passwordHash;
  return obj;
}

/**
 * GET /api/auth/me
 * Get current user profile (requires auth)
 */
router.get('/me', authenticate, async (req, res) => {
  try {
    res.json({ user: safeUserJSON(req.user) });
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
    res.json({ user: safeUserJSON(user) });
  } catch (error) {
    console.error('Update profile error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});
/**
 * POST /api/auth/dev-login
 * DEV ONLY — Auto-creates a test user and returns a valid JWT.
 * This exists so the Flutter app's bypass login can get a real token.
 */
router.post('/dev-login', async (req, res) => {
  try {
    const testEmail = 'dev@rouniity.test';
    const testPhone = '9999999999';
    
    let user = await User.findOne({ email: testEmail });
    
    if (!user) {
      user = new User({
        name: 'Dev User',
        email: testEmail,
        phone: testPhone,
        passwordHash: 'devpassword123',
      });
      await user.save();
      console.log('[DEV] Created test user:', testEmail);
    }
    
    const token = jwt.sign(
      { userId: user._id },
      process.env.JWT_SECRET || 'secret',
      { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
    );
    
    res.json({
      message: 'Dev login successful',
      token,
      user: safeUserJSON(user),
    });
  } catch (error) {
    console.error('Dev login error:', error);
    res.status(500).json({ error: 'Dev login failed' });
  }
});

module.exports = router;
