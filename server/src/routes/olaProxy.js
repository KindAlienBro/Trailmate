const express = require('express');
const axios = require('axios');
const { authenticate } = require('../middleware/auth');
const ApiUsage = require('../models/ApiUsage');

const router = express.Router();

// ── Public routes (no auth) ──────────────────────────────────────────────────
// /nearby is intentionally public: it's a maps proxy with a server-side API key.
// No user data is returned — it only forwards location-based search queries.


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
        'X-Request-Id': `rouniity-${Date.now()}`,
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
 * GET /api/maps/nearby  ── PUBLIC (no auth required)
 * Proxy to Ola Maps Nearby Search API
 * Query: location (lat,lng), types (gas_station, restaurant, etc.)
 */
router.get('/nearby', async (req, res) => {
  const { location, types, radius } = req.query;
  if (!location || !types) {
    return res.status(400).json({ error: 'location and types are required' });
  }
  const params = { layers: 'venue', location, types, limit: 20, size: 20 };
  if (radius) params.radius = radius;
  
  try {
    const apiKey = getApiKey();
    params.api_key = apiKey;
    const response = await axios.get(`${OLA_BASE_URL}/places/v1/nearbysearch`, {
      params,
      headers: { 'X-Request-Id': `rouniity-nearby-${Date.now()}` },
      timeout: 15000,
    });
    
    const data = response.data;
    if (data && data.predictions) {
      // Limit to first 20 predictions to avoid excessive detail requests
      const limit = Math.min(data.predictions.length, 20);
      data.predictions = data.predictions.slice(0, limit);
      
      const promises = data.predictions.map(async (p) => {
        try {
          if (p.place_id) {
            const detailUrl = `${OLA_BASE_URL}/places/v1/details?place_id=${p.place_id}&api_key=${apiKey}`;
            const detailRes = await axios.get(detailUrl, { timeout: 5000 });
            const geom = detailRes.data?.result?.geometry?.location;
            if (geom) {
              p.geometry = { location: geom };
              console.log(`[OlaProxy] Successfully fetched geometry for ${p.place_id}:`, geom);
            } else {
              console.log(`[OlaProxy] No geometry found in details for ${p.place_id}`);
            }
          }
        } catch (e) {
          console.error(`[OlaProxy] Failed to fetch details for ${p.place_id}:`, e.message);
        }
        return p;
      });
      await Promise.all(promises);
    }
    
    res.json(data);
  } catch (error) {
    const status = error.response?.status || 500;
    const data = error.response?.data || {};
    const message = data.reason || data.status || data.error || error.message;
    console.error('Nearby search proxy error:', message);
    if (error.response?.data) {
      console.error('Full Ola API Error:', JSON.stringify(data, null, 2));
    }
    console.error('Request query was:', req.query);
    res.status(status).json({ error: `Nearby Search API error: ${message}` });
  }
});

// ── Authenticated routes ─────────────────────────────────────────────────────
// All routes below this line require a valid Bearer token.
router.use(authenticate);

// Middleware to track API usage for authenticated routes
router.use((req, res, next) => {
  const start = Date.now();
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
        error: res.statusCode >= 400 ? (res.statusMessage || 'Error') : null,
      });
    } catch (err) {
      console.error('Failed to log API usage:', err.message);
    }
  });
  next();
});

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
      if (mode === 'two_wheeler' || mode === 'bike') {
        params.mode = 'motorcycle';
      } else if (mode === 'walking' || mode === 'walk') {
        params.mode = 'walking';
      } else {
        params.mode = mode;
      }
    }
    if (waypoints) {
      const wpArray = waypoints.split('|');
      if (wpArray.length > 20) {
        const step = Math.ceil(wpArray.length / 20);
        params.waypoints = wpArray.filter((_, i) => i % step === 0).slice(0, 20).join('|');
        console.log(`[OlaProxy] Downsampled ${wpArray.length} waypoints to 20`);
      } else {
        params.waypoints = waypoints;
      }
    }
    if (req.body.alternatives) {
      params.alternatives = true;
    }

    const response = await axios.post(
      `${OLA_BASE_URL}/routing/v1/directions`,
      null,
      {
        params,
        headers: { 'X-Request-Id': `rouniity-dir-${Date.now()}` },
        timeout: 15000,
      }
    );

    res.json(response.data);
  } catch (error) {
    const status = error.response?.status || 500;
    const data = error.response?.data || {};
    const message = data.reason || data.status || data.error || error.message;
    
    console.error('Directions proxy error:', message);
    if (error.response?.data) {
      console.error('Full Ola API Error:', JSON.stringify(error.response.data, null, 2));
    }
    console.error('Request params were:', req.body);
    res.status(status).json({ error: `Directions API error: ${message}` });
  }
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
        headers: { 'X-Request-Id': `rouniity-dm-${Date.now()}` },
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
        headers: { 'X-Request-Id': `rouniity-snap-${Date.now()}` },
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
