const express = require('express');
const axios = require('axios');
const { authenticate } = require('../middleware/auth');
const ApiUsage = require('../models/ApiUsage');

const router = express.Router();

// All proxy routes require authentication
router.use(authenticate);

// Middleware to track API usage
router.use((req, res, next) => {
  const start = Date.now();
  
  // Listen for the response to finish
  res.on('finish', async () => {
    try {
      const latency = Date.now() - start;
      const endpoint = req.path;
      
      await ApiUsage.create({
        userId: req.userId,
        endpoint,
        method: req.method,
        status: res.statusCode,
        latency,
        error: res.statusCode >= 400 ? (res.statusMessage || 'Error') : null
      });
    } catch (err) {
      console.error('Failed to log API usage:', err.message);
    }
  });
  
  next();
});

const OLA_BASE_URL = 'https://api.olamaps.io';
const getApiKey = () => process.env.OLA_MAPS_API_KEY;

/**
 * Helper to proxy requests to Ola Maps API
 */
async function proxyToOla(olaPath, queryParams, res) {
  try {
    const params = { ...queryParams, api_key: getApiKey() };
    const response = await axios.get(`${OLA_BASE_URL}${olaPath}`, {
      params,
      headers: {
        'X-Request-Id': `trailmate-${Date.now()}`,
      },
      timeout: 15000,
    });
    return res.json(response.data);
  } catch (error) {
    const status = error.response?.status || 500;
    const message = error.response?.data?.error || error.message;
    console.error(`Ola Maps proxy error [${olaPath}]:`, message);
    return res.status(status).json({ error: `Maps API error: ${message}` });
  }
}

/**
 * GET /api/maps/usage
 * Get API token usage for the current user
 */
router.get('/usage', async (req, res) => {
  try {
    const used = await ApiUsage.countDocuments({ userId: req.userId });
    const limit = 10000; // Mock fixed token limit per user
    res.json({ used, limit });
  } catch (error) {
    console.error('Failed to get API usage:', error.message);
    res.status(500).json({ error: 'Failed to retrieve API usage' });
  }
});

/**
 * POST /api/maps/directions
 * Proxy to Ola Maps Directions API
 * Query: origin, destination, waypoints (optional, pipe-separated)
 */
router.post('/directions', async (req, res) => {
  try {
    const { origin, destination, waypoints, mode } = req.body;

    if (!origin || !destination) {
      return res.status(400).json({ error: 'Origin and destination are required' });
    }

    const params = {
      origin,
      destination,
      api_key: getApiKey(),
      steps: true,
    };
    if (mode) {
      params.mode = mode;
    }
    if (waypoints) {
      params.waypoints = waypoints;
    }
    if (req.body.alternatives) {
      params.alternatives = true;
    }

    const response = await axios.post(
      `${OLA_BASE_URL}/routing/v1/directions`,
      null,
      {
        params,
        headers: { 'X-Request-Id': `trailmate-dir-${Date.now()}` },
        timeout: 15000,
      }
    );

    res.json(response.data);
  } catch (error) {
    const status = error.response?.status || 500;
    const message = error.response?.data?.error || error.message;
    console.error('Directions proxy error:', message);
    res.status(status).json({ error: `Directions API error: ${message}` });
  }
});

/**
 * GET /api/maps/nearby
 * Proxy to Ola Maps Nearby Search API
 * Query: location (lat,lng), types (gas_station, restaurant, etc.)
 */
router.get('/nearby', (req, res) => {
  const { location, types, radius } = req.query;
  if (!location || !types) {
    return res.status(400).json({ error: 'location and types are required' });
  }
  const params = { layers: 'venue', location, types };
  if (radius) params.radius = radius;
  return proxyToOla('/places/v1/nearbysearch', params, res);
});

/**
 * GET /api/maps/autocomplete
 * Proxy to Ola Maps Autocomplete API
 * Query: input (search text), location (optional, for bias)
 */
router.get('/autocomplete', (req, res) => {
  const { input, location } = req.query;
  if (!input) {
    return res.status(400).json({ error: 'input is required' });
  }
  const params = { input };
  if (location) params.location = location;
  return proxyToOla('/places/v1/autocomplete', params, res);
});

/**
 * GET /api/maps/geocode
 * Proxy to Ola Maps Geocoding API
 * Query: address
 */
router.get('/geocode', (req, res) => {
  const { address } = req.query;
  if (!address) {
    return res.status(400).json({ error: 'address is required' });
  }
  return proxyToOla('/places/v1/geocode', { address }, res);
});

/**
 * GET /api/maps/reverse-geocode
 * Proxy to Ola Maps Reverse Geocoding API
 * Query: latlng (lat,lng)
 */
router.get('/reverse-geocode', (req, res) => {
  const { latlng } = req.query;
  if (!latlng) {
    return res.status(400).json({ error: 'latlng is required' });
  }
  return proxyToOla('/places/v1/reverse-geocode', { latlng }, res);
});

/**
 * POST /api/maps/distance-matrix
 * Proxy to Ola Maps Distance Matrix API
 * Body: origins, destinations (pipe-separated lat,lng pairs)
 */
router.post('/distance-matrix', async (req, res) => {
  try {
    const { origins, destinations } = req.body;
    if (!origins || !destinations) {
      return res.status(400).json({ error: 'origins and destinations are required' });
    }

    const response = await axios.get(
      `${OLA_BASE_URL}/routing/v1/distanceMatrix`,
      {
        params: { origins, destinations, api_key: getApiKey() },
        headers: { 'X-Request-Id': `trailmate-dm-${Date.now()}` },
        timeout: 15000,
      }
    );

    res.json(response.data);
  } catch (error) {
    const status = error.response?.status || 500;
    const message = error.response?.data?.error || error.message;
    console.error('Distance matrix proxy error:', message);
    res.status(status).json({ error: `Distance Matrix error: ${message}` });
  }
});

/**
 * POST /api/maps/snap-to-road
 * Proxy to Ola Maps Snap to Road API
 * Body: points (pipe-separated lat,lng pairs)
 */
router.post('/snap-to-road', async (req, res) => {
  try {
    const { points } = req.body;
    if (!points) {
      return res.status(400).json({ error: 'points are required' });
    }

    const response = await axios.post(
      `${OLA_BASE_URL}/routing/v1/snapToRoad`,
      null,
      {
        params: { points, api_key: getApiKey() },
        headers: { 'X-Request-Id': `trailmate-snap-${Date.now()}` },
        timeout: 15000,
      }
    );

    res.json(response.data);
  } catch (error) {
    const status = error.response?.status || 500;
    const message = error.response?.data?.error || error.message;
    console.error('Snap to road proxy error:', message);
    res.status(status).json({ error: `Snap to Road error: ${message}` });
  }
});

module.exports = router;
