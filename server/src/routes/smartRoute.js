const express = require('express');
const axios = require('axios');
const { authenticate } = require('../middleware/auth');

const router = express.Router();
router.use(authenticate);

const OLA_BASE_URL = 'https://api.olamaps.io';
const OVERPASS_URL = 'https://lz4.overpass-api.de/api/interpreter';

const getOlaApiKey = () => process.env.OLA_MAPS_API_KEY;

/**
 * Simplified linear interpolation between two coordinates
 */
function interpolate(lat1, lng1, lat2, lng2, fraction) {
  return {
    lat: lat1 + (lat2 - lat1) * fraction,
    lng: lng1 + (lng2 - lng1) * fraction,
  };
}

/**
 * Generate an Overpass QL query based on adventure mode
 */
function buildOverpassQuery(lat1, lng1, lat2, lng2, mode) {
  const radius = mode === 'full_adventure' ? 5000 : 4000; // 5km or 4km to prevent 504 timeout

  let query = `[out:json][timeout:25];\n(\n`;

  if (mode === 'full_adventure') {
    // Off-road tracks, water crossings, peaks
    query += `
      node(around:${radius}, ${lat1}, ${lng1})["ford"="yes"];
      node(around:${radius}, ${lat1}, ${lng1})["natural"="peak"];
      way(around:${radius}, ${lat1}, ${lng1})["highway"="track"];
      node(around:${radius}, ${lat1}, ${lng1})["waterway"="waterfall"];
      node(around:${radius}, ${lat1}, ${lng1})["waterway"="dam"];
      way(around:${radius}, ${lat1}, ${lng1})["natural"="water"];
      node(around:${radius}, ${lat2}, ${lng2})["ford"="yes"];
      node(around:${radius}, ${lat2}, ${lng2})["natural"="peak"];
      way(around:${radius}, ${lat2}, ${lng2})["highway"="track"];
      node(around:${radius}, ${lat2}, ${lng2})["waterway"="waterfall"];
      node(around:${radius}, ${lat2}, ${lng2})["waterway"="dam"];
      way(around:${radius}, ${lat2}, ${lng2})["natural"="water"];
    `;
  } else if (mode === 'cultural') {
    query += `
      node(around:${radius}, ${lat1}, ${lng1})["historic"];
      node(around:${radius}, ${lat1}, ${lng1})["tourism"="museum"];
      node(around:${radius}, ${lat1}, ${lng1})["historic"="archaeological_site"];
      node(around:${radius}, ${lat2}, ${lng2})["historic"];
      node(around:${radius}, ${lat2}, ${lng2})["tourism"="museum"];
      node(around:${radius}, ${lat2}, ${lng2})["historic"="archaeological_site"];
    `;
  } else if (mode === 'foodie') {
    query += `
      node(around:${radius}, ${lat1}, ${lng1})["amenity"="restaurant"];
      node(around:${radius}, ${lat1}, ${lng1})["amenity"="cafe"];
      node(around:${radius}, ${lat1}, ${lng1})["shop"="bakery"];
      node(around:${radius}, ${lat2}, ${lng2})["amenity"="restaurant"];
      node(around:${radius}, ${lat2}, ${lng2})["amenity"="cafe"];
      node(around:${radius}, ${lat2}, ${lng2})["shop"="bakery"];
    `;
  } else if (mode === 'coastal') {
    query += `
      way(around:${radius}, ${lat1}, ${lng1})["natural"="coastline"];
      node(around:${radius}, ${lat1}, ${lng1})["natural"="beach"];
      node(around:${radius}, ${lat1}, ${lng1})["leisure"="marina"];
      way(around:${radius}, ${lat2}, ${lng2})["natural"="coastline"];
      node(around:${radius}, ${lat2}, ${lng2})["natural"="beach"];
      node(around:${radius}, ${lat2}, ${lng2})["leisure"="marina"];
    `;
  } else if (mode === 'spiritual') {
    query += `
      node(around:${radius}, ${lat1}, ${lng1})["amenity"="place_of_worship"];
      node(around:${radius}, ${lat2}, ${lng2})["amenity"="place_of_worship"];
    `;
  } else if (mode === 'wildlife') {
    query += `
      way(around:${radius}, ${lat1}, ${lng1})["boundary"="national_park"];
      way(around:${radius}, ${lat1}, ${lng1})["leisure"="nature_reserve"];
      node(around:${radius}, ${lat1}, ${lng1})["tourism"="zoo"];
      way(around:${radius}, ${lat2}, ${lng2})["boundary"="national_park"];
      way(around:${radius}, ${lat2}, ${lng2})["leisure"="nature_reserve"];
      node(around:${radius}, ${lat2}, ${lng2})["tourism"="zoo"];
    `;
  } else {
    // Adventure (Viewpoints, waterfalls, historic ruins, dams, lakes, caves, attractions)
    query += `
      node(around:${radius}, ${lat1}, ${lng1})["tourism"="viewpoint"];
      node(around:${radius}, ${lat1}, ${lng1})["waterway"="waterfall"];
      node(around:${radius}, ${lat1}, ${lng1})["historic"="ruins"];
      node(around:${radius}, ${lat1}, ${lng1})["waterway"="dam"];
      node(around:${radius}, ${lat1}, ${lng1})["natural"="cave_entrance"];
      node(around:${radius}, ${lat1}, ${lng1})["tourism"="attraction"];
      way(around:${radius}, ${lat1}, ${lng1})["natural"="water"];
      node(around:${radius}, ${lat2}, ${lng2})["tourism"="viewpoint"];
      node(around:${radius}, ${lat2}, ${lng2})["waterway"="waterfall"];
      node(around:${radius}, ${lat2}, ${lng2})["historic"="ruins"];
      node(around:${radius}, ${lat2}, ${lng2})["waterway"="dam"];
      node(around:${radius}, ${lat2}, ${lng2})["natural"="cave_entrance"];
      node(around:${radius}, ${lat2}, ${lng2})["tourism"="attraction"];
      way(around:${radius}, ${lat2}, ${lng2})["natural"="water"];
    `;
  }

  // out center is important for ways (like highway=track) to get a single lat/lng
  query += `\n);\nout center 30;\n`;
  return query;
}

/**
 * Maps OSM tags to our UI waypoint types
 */
function parseOsmElement(el) {
  const tags = el.tags || {};
  let name = tags.name || tags['name:en'] || 'Unknown Spot';
  let type = 'scenic';
  let reason = 'An interesting spot to check out.';

  if (tags.tourism === 'viewpoint') {
    type = 'viewpoint';
    reason = 'A beautiful scenic viewpoint.';
    if (name === 'Unknown Spot') name = 'Scenic Viewpoint';
  } else if (tags.waterway === 'waterfall') {
    type = 'waterfall';
    reason = 'A majestic waterfall.';
    if (name === 'Unknown Spot') name = 'Hidden Waterfall';
  } else if (tags.waterway === 'dam') {
    type = 'dam';
    reason = 'An impressive dam structure.';
    if (name === 'Unknown Spot') name = 'Scenic Dam';
  } else if (tags.natural === 'water') {
    type = 'lake';
    reason = 'A beautiful body of water.';
    if (name === 'Unknown Spot') name = 'Tranquil Lake';
  } else if (tags.natural === 'cave_entrance') {
    type = 'cave';
    reason = 'A fascinating cave entrance.';
    if (name === 'Unknown Spot') name = 'Mysterious Cave';
  } else if (tags.tourism === 'attraction') {
    type = 'attraction';
    reason = 'A notable local tourist attraction.';
    if (name === 'Unknown Spot') name = 'Local Attraction';
  } else if (tags.historic === 'monument' || tags.historic === 'archaeological_site') {
    type = 'monument';
    reason = 'A remarkable historical monument.';
    if (name === 'Unknown Spot') name = 'Historical Monument';
  } else if (tags.tourism === 'museum') {
    type = 'museum';
    reason = 'A fascinating museum.';
    if (name === 'Unknown Spot') name = 'Local Museum';
  } else if (tags.amenity === 'restaurant') {
    type = 'restaurant';
    reason = 'A highly rated local restaurant.';
    if (name === 'Unknown Spot') name = 'Local Restaurant';
  } else if (tags.amenity === 'cafe') {
    type = 'cafe';
    reason = 'A great place to grab coffee and snacks.';
    if (name === 'Unknown Spot') name = 'Cozy Cafe';
  } else if (tags.shop === 'bakery') {
    type = 'bakery';
    reason = 'Freshly baked goods available here.';
    if (name === 'Unknown Spot') name = 'Local Bakery';
  } else if (tags.natural === 'beach' || tags.natural === 'coastline') {
    type = 'beach';
    reason = 'A beautiful coastal spot.';
    if (name === 'Unknown Spot') name = 'Scenic Beach';
  } else if (tags.leisure === 'marina') {
    type = 'marina';
    reason = 'A lovely marina with boats.';
    if (name === 'Unknown Spot') name = 'Local Marina';
  } else if (tags.amenity === 'place_of_worship') {
    type = 'worship';
    reason = 'A peaceful spiritual center.';
    if (name === 'Unknown Spot') name = 'Spiritual Center';
  } else if (tags.boundary === 'national_park' || tags.leisure === 'nature_reserve') {
    type = 'national_park';
    reason = 'A protected nature reserve.';
    if (name === 'Unknown Spot') name = 'Nature Reserve';
  } else if (tags.tourism === 'zoo') {
    type = 'zoo';
    reason = 'A wildlife sanctuary or zoo.';
    if (name === 'Unknown Spot') name = 'Wildlife Sanctuary';
  } else if (tags.historic) {
    type = 'heritage';
    reason = 'Historical ruins to explore.';
    if (name === 'Unknown Spot') name = 'Ancient Ruins';
  } else if (tags.ford === 'yes') {
    type = 'water_crossing';
    reason = 'An exciting water crossing / river ford.';
    if (name === 'Unknown Spot') name = 'River Ford';
  } else if (tags.natural === 'peak') {
    type = 'mountain_pass';
    reason = 'A high mountain peak.';
    if (name === 'Unknown Spot') name = 'Mountain Peak';
  } else if (tags.highway === 'track') {
    type = 'jungle';
    reason = 'An unpaved dirt track / off-road trail.';
    if (name === 'Unknown Spot') name = 'Off-Road Trail';
  }

  // Determine lat/lng depending on if it's a node or a way (center)
  const lat = el.lat || (el.center && el.center.lat);
  const lng = el.lon || (el.center && el.center.lon);

  return {
    lat,
    lng,
    name,
    reason,
    type
  };
}

/**
 * Call Overpass API to get real-world adventure waypoints
 */
async function generateAdventureWaypoints(originLat, originLng, destLat, destLng, mode) {
  // Pick two points roughly 33% and 66% along the direct line
  const p1 = interpolate(originLat, originLng, destLat, destLng, 0.33);
  const p2 = interpolate(originLat, originLng, destLat, destLng, 0.66);

  const query = buildOverpassQuery(p1.lat, p1.lng, p2.lat, p2.lng, mode);

  const response = await axios.post(OVERPASS_URL, `data=${encodeURIComponent(query)}`, {
    headers: { 
      'Content-Type': 'application/x-www-form-urlencoded',
      'Accept': 'application/json',
      'User-Agent': 'TrialMateApp/1.0'
    },
    timeout: 25000,
  });

  const elements = response.data?.elements || [];
  if (elements.length === 0) {
    return { waypoints: [], routeCharacter: 'A scenic route.' };
  }

  // Deduplicate and ensure diversity of waypoint types
  const waypoints = [];
  const seen = new Set();
  const typeCount = {};

  // Shuffle elements to mix peaks, waterfalls, tracks, etc.
  elements.sort(() => Math.random() - 0.5);

  for (const el of elements) {
    const wp = parseOsmElement(el);
    if (!wp.lat || !wp.lng) continue;
    
    // Max 3 of each specific type to ensure variety
    if ((typeCount[wp.type] || 0) >= 3) continue;
    
    // Simple deduplication based on name and close proximity
    const key = `${wp.name}-${wp.lat.toFixed(2)}-${wp.lng.toFixed(2)}`;
    if (!seen.has(key)) {
      seen.add(key);
      waypoints.push(wp);
      typeCount[wp.type] = (typeCount[wp.type] || 0) + 1;
    }
    if (waypoints.length >= 10) break;
  }

  // Sort waypoints sequentially along the Origin-Destination line to prevent backtracking
  const A = { lat: destLat - originLat, lng: destLng - originLng };
  const lengthSquared = A.lat * A.lat + A.lng * A.lng;
  
  if (lengthSquared > 0) {
    waypoints.sort((wp1, wp2) => {
      const B1 = { lat: wp1.lat - originLat, lng: wp1.lng - originLng };
      const proj1 = (A.lat * B1.lat + A.lng * B1.lng) / lengthSquared;
      
      const B2 = { lat: wp2.lat - originLat, lng: wp2.lng - originLng };
      const proj2 = (A.lat * B2.lat + A.lng * B2.lng) / lengthSquared;
      
      return proj1 - proj2;
    });
  }

  const routeCharacter = mode === 'full_adventure' 
    ? 'A hardcore adventure hitting unpaved tracks and wild terrain.'
    : 'A beautiful scenic route hitting viewpoints and nature spots.';

  return { waypoints, routeCharacter };
}

/**
 * POST /api/maps/smart-route
 *
 * Body: { origin, destination, mode, transportMode }
 *   origin/destination: "lat,lng" strings
 *   mode: "highway" | "adventure" | "full_adventure"
 *   transportMode: "driving" | "two_wheeler" | "walking" | "bicycling"
 *
 * Returns: { routes, aiWaypoints, mode, routeCharacter }
 */
router.post('/smart-route', async (req, res) => {
  try {
    const { origin, destination, mode = 'highway', transportMode } = req.body;

    if (!origin || !destination) {
      return res.status(400).json({ error: 'Origin and destination are required' });
    }

    const [originLat, originLng] = origin.split(',').map(Number);
    const [destLat, destLng] = destination.split(',').map(Number);

    // ── Highway mode: direct route, no extra processing ──
    if (mode === 'highway') {
      const params = {
        origin,
        destination,
        api_key: getOlaApiKey(),
        steps: true,
      };
      if (transportMode) params.mode = transportMode;

      const response = await axios.post(
        `${OLA_BASE_URL}/routing/v1/directions`,
        null,
        {
          params,
          headers: { 'X-Request-Id': `trailmate-smart-${Date.now()}` },
          timeout: 15000,
        }
      );

      return res.json({
        ...response.data,
        aiWaypoints: [],
        mode: 'highway',
        routeCharacter: 'Direct highway route — fastest path to your destination.',
      });
    }

    // ── Adventure / Full Adventure: use OpenStreetMap Overpass API ──
    console.log(`[SmartRoute] Fetching OSM waypoints for ${mode}: ${origin} → ${destination}`);

    const overpassResult = await generateAdventureWaypoints(
      originLat, originLng, destLat, destLng, mode
    );

    console.log(`[SmartRoute] Overpass found ${overpassResult.waypoints.length} authentic waypoints`);

    // Build waypoints string for Ola Directions API (pipe-separated lat,lng pairs)
    const waypointsStr = overpassResult.waypoints
      .map(wp => `${wp.lat},${wp.lng}`)
      .join('|');

    // Call Ola Directions with OSM waypoints
    let url = `${OLA_BASE_URL}/routing/v1/directions?origin=${origin}&destination=${destination}&api_key=${getOlaApiKey()}&steps=true`;
    if (transportMode) url += `&mode=${transportMode}`;
    if (waypointsStr) url += `&waypoints=${waypointsStr}`; // Do not URL encode the pipe character

    const response = await axios.post(
      url,
      null,
      {
        headers: { 'X-Request-Id': `trailmate-smart-${Date.now()}` },
        timeout: 15000,
      }
    );

    return res.json({
      ...response.data,
      aiWaypoints: overpassResult.waypoints,
      mode,
      routeCharacter: overpassResult.routeCharacter,
    });

  } catch (error) {
    const message = error.response?.data?.error || error.message;
    console.error('[SmartRoute] Error:', message);

    // Fallback: if Overpass or Ola with waypoints fails, return a direct route
    console.log('[SmartRoute] Falling back to direct route');
    try {
      const { origin, destination, transportMode } = req.body;
      let fallbackUrl = `${OLA_BASE_URL}/routing/v1/directions?origin=${origin}&destination=${destination}&api_key=${getOlaApiKey()}&steps=true`;
      if (transportMode) fallbackUrl += `&mode=${transportMode}`;

      const fallback = await axios.post(
        fallbackUrl,
        null,
        { timeout: 15000 }
      );

      return res.json({
        ...fallback.data,
        aiWaypoints: [],
        mode: 'highway',
        routeCharacter: 'Direct route (fallback mode).',
      });
    } catch (fallbackError) {
      console.error('[SmartRoute] Fallback Error:', fallbackError.message);
      return res.status(500).json({ error: 'Failed to generate any route.' });
    }
  }
});

module.exports = router;
