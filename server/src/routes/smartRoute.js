const express = require('express');
const axios = require('axios');
const { authenticate } = require('../middleware/auth');

const router = express.Router();
router.use(authenticate);

const OLA_BASE_URL = 'https://api.olamaps.io';

const OVERPASS_MIRRORS = [
  'https://overpass-api.de/api/interpreter',
  'https://lz4.overpass-api.de/api/interpreter',
  'https://z.overpass-api.de/api/interpreter',
  'https://overpass.kumi.systems/api/interpreter',
  'https://maps.mail.ru/osm/tools/overpass/api/interpreter',
  'https://overpass.openstreetmap.ru/api/interpreter',
];

const getOlaApiKey = () => process.env.OLA_MAPS_API_KEY;
const getOpenTripMapKey = () => process.env.OPENTRIPMAP_API_KEY;

// ─────────────────────── Geometry Helpers ───────────────────────

function haversineKm(lat1, lng1, lat2, lng2) {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLng = ((lng2 - lng1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function routeBoundingBox(lat1, lng1, lat2, lng2, paddingKm = 20) {
  const paddingDeg = paddingKm / 111; 
  const south = Math.min(lat1, lat2) - paddingDeg;
  const north = Math.max(lat1, lat2) + paddingDeg;
  const west = Math.min(lng1, lng2) - paddingDeg;
  const east = Math.max(lng1, lng2) + paddingDeg;
  return { south, north, west, east };
}

// ─────────────────────── Ola Maps Nearby Search (PRIMARY) ───────────────────────

/**
 * Fetches POIs using the Ola Maps Nearby Search API.
 * This is the most reliable source since we already have a working API key.
 * Queries each sampled point along the route corridor.
 */
async function fetchOlaNearbyPlaces(sampledPoints, mode) {
  const apiKey = getOlaApiKey();
  if (!apiKey) return [];

  // Map route modes to Ola Maps place types
  let types = 'tourist_attraction';
  switch (mode) {
    case 'cultural':
      types = 'tourist_attraction,museum,hindu_temple,church,mosque,point_of_interest';
      break;
    case 'spiritual':
      types = 'hindu_temple,church,mosque,place_of_worship,tourist_attraction';
      break;
    case 'foodie':
      types = 'restaurant,cafe,bakery,food';
      break;
    case 'coastal':
      types = 'tourist_attraction,natural_feature,park';
      break;
    case 'wildlife':
      types = 'park,zoo,natural_feature,tourist_attraction';
      break;
    case 'adventure':
    case 'full_adventure':
      types = 'tourist_attraction,natural_feature,park,point_of_interest';
      break;
    default:
      types = 'tourist_attraction,point_of_interest';
      break;
  }

  // Query a subset of sampled points to stay within rate limits (max 5 queries)
  const step = Math.max(1, Math.floor(sampledPoints.length / 5));
  const queryPoints = sampledPoints.filter((_, i) => i % step === 0);

  const promises = queryPoints.map(async (pt) => {
    try {
      // Try each type separately to maximize results
      const typeList = types.split(',').slice(0, 3); // Max 3 types per point
      const typePromises = typeList.map(async (type) => {
        try {
          const url = `${OLA_BASE_URL}/places/v1/nearbysearch?layers=venue&types=${type.trim()}&location=${pt.lat},${pt.lng}&radius=15000&limit=10&api_key=${apiKey}`;
          const res = await axios.get(url, {
            timeout: 10000,
            headers: { 'X-Request-Id': `trailmate-poi-${Date.now()}` }
          });
          return res.data?.predictions || [];
        } catch {
          return [];
        }
      });
      const allResults = await Promise.all(typePromises);
      return allResults.flat();
    } catch (err) {
      console.log(`[SmartRoute] Ola nearby search failed for point ${pt.lat},${pt.lng}: ${err.message}`);
      return [];
    }
  });

  const results = await Promise.all(promises);
  const places = [];
  const seenIds = new Set();

  for (const predictions of results) {
    for (const p of predictions) {
      if (seenIds.has(p.place_id)) continue;
      seenIds.add(p.place_id);

      // Extract name from main_text (format: "Name || Area")
      let name = p.structured_formatting?.main_text || p.description?.split(',')[0] || '';
      name = name.split('||')[0].trim();
      if (!name) continue;

      // Determine type from the prediction's types array
      let type = 'scenic';
      const pTypes = (p.types || []).join(',');
      if (pTypes.includes('museum')) type = 'museum';
      else if (pTypes.includes('temple') || pTypes.includes('church') || pTypes.includes('mosque') || pTypes.includes('worship')) type = 'worship';
      else if (pTypes.includes('zoo')) type = 'zoo';
      else if (pTypes.includes('park') || pTypes.includes('nature')) type = 'national_park';
      else if (pTypes.includes('restaurant') || pTypes.includes('food')) type = 'restaurant';
      else if (pTypes.includes('cafe')) type = 'cafe';
      else if (pTypes.includes('tourist_attraction') || pTypes.includes('point_of_interest')) type = 'attraction';

      // We need lat/lng — fetch from place details if not available
      // Ola nearbysearch returns distance_meters but we need to geocode via the reference
      // For now, estimate position from the queried point (will be refined by dedup)
      // Actually, we need place details for the lat/lng
      const placeRef = p.reference;
      if (placeRef) {
        try {
          const detailUrl = `${OLA_BASE_URL}/places/v1/details?place_id=${p.place_id}&api_key=${apiKey}`;
          const detailRes = await axios.get(detailUrl, {
            timeout: 5000,
            headers: { 'X-Request-Id': `trailmate-detail-${Date.now()}` }
          });
          const geom = detailRes.data?.result?.geometry?.location;
          if (geom) {
            places.push({
              lat: geom.lat,
              lng: geom.lng,
              name,
              reason: `A notable ${type === 'worship' ? 'spiritual site' : type === 'attraction' ? 'tourist attraction' : type === 'museum' ? 'museum' : 'place'} in the area.`,
              type,
              notability: 8,
              source: 'ola_maps'
            });
          }
        } catch {
          // Skip if detail fetch fails
        }
      }
    }
  }

  console.log(`[SmartRoute] Ola Maps Nearby Search returned ${places.length} places`);
  return places;
}

// ─────────────────────── OpenTripMap Integration ───────────────────────

async function fetchOpenTripMapPlaces(lat1, lng1, lat2, lng2, mode) {
  const apiKey = getOpenTripMapKey();
  if (!apiKey || apiKey === 'YOUR_OPENTRIPMAP_KEY_HERE') {
    return [];
  }

  const bbox = routeBoundingBox(lat1, lng1, lat2, lng2, 15);
  
  let kinds = '';
  switch (mode) {
    case 'cultural': kinds = 'cultural,historic,architecture,museums'; break;
    case 'foodie': kinds = 'foods'; break;
    case 'coastal': kinds = 'beaches'; break;
    case 'spiritual': kinds = 'religion'; break;
    case 'wildlife': kinds = 'natural'; break;
    case 'adventure': 
    case 'full_adventure': 
      kinds = 'natural,historic,other_nature'; 
      break;
    default: kinds = 'interesting_places'; break;
  }

  const url = `https://api.opentripmap.com/0.1/en/places/bbox?lon_min=${bbox.west}&lat_min=${bbox.south}&lon_max=${bbox.east}&lat_max=${bbox.north}&kinds=${kinds}&rate=2&format=json&apikey=${apiKey}`;

  try {
    const response = await axios.get(url, { timeout: 15000 });
    const places = response.data || [];
    
    return places.map(p => {
      let type = 'scenic';
      if (p.kinds.includes('museum')) type = 'museum';
      else if (p.kinds.includes('religion')) type = 'worship';
      else if (p.kinds.includes('historic') || p.kinds.includes('architecture')) type = 'heritage';
      else if (p.kinds.includes('beach')) type = 'beach';
      else if (p.kinds.includes('foods')) type = 'restaurant';
      else if (p.kinds.includes('natural')) type = 'national_park';

      return {
        lat: p.point.lat,
        lng: p.point.lon,
        name: p.name,
        reason: 'A highly rated must-visit spot.',
        type: type,
        notability: p.rate * 10, 
        source: 'opentripmap'
      };
    }).filter(p => p.name);
  } catch (error) {
    console.error(`[SmartRoute] OpenTripMap error: ${error.message}`);
    return [];
  }
}

// ─────────────────────── Wikipedia GeoSearch Integration ───────────────────────

/**
 * Fetches notable landmarks directly from Wikipedia. 
 * This is incredibly fast, 100% free, never times out, and guarantees famous spots!
 */
async function fetchWikipediaPlaces(sampledPoints) {
  const places = [];
  let successCount = 0;
  let failCount = 0;

  try {
    const promises = sampledPoints.map(async (pt) => {
      try {
        // 10km radius around each sampled point, max 10 results per point
        const url = `https://en.wikipedia.org/w/api.php?action=query&list=geosearch&gscoord=${pt.lat}|${pt.lng}&gsradius=10000&gslimit=10&format=json`;
        const res = await axios.get(url, {
          timeout: 8000,
          headers: {
            'User-Agent': 'TrailMateApp/1.0 (https://github.com/trailmate; trailmate@example.com)',
            'Api-User-Agent': 'TrailMateApp/1.0'
          }
        });
        if (res?.data?.query?.geosearch) {
          successCount++;
          return res.data.query.geosearch;
        }
        return [];
      } catch (err) {
        failCount++;
        console.log(`[SmartRoute] Wikipedia geosearch failed for ${pt.lat},${pt.lng}: ${err.message}`);
        return [];
      }
    });

    const results = await Promise.all(promises);

    for (const items of results) {
      for (const item of items) {
        places.push({
          lat: item.lat,
          lng: item.lon,
          name: item.title,
          reason: 'A notable Wikipedia landmark.',
          type: 'heritage',
          notability: 10, // High notability since it has a Wiki page
          source: 'wikipedia'
        });
      }
    }
    
    console.log(`[SmartRoute] Wikipedia: ${successCount} points succeeded, ${failCount} failed, ${places.length} total places`);
  } catch (err) {
    console.error(`[SmartRoute] Wikipedia API error: ${err.message}`);
  }
  return places;
}

// ─────────────────────── Overpass Query Builder (Per-point Around Radius) ───────────────────────

/**
 * Build tag filters for each mode. Returns an array of filter strings.
 * Using per-point around-radius queries instead of a single giant bounding box
 * to avoid Overpass timeouts on long routes.
 */
function getOverpassTagFilters(mode) {
  const nameFilter = `["name"]`;
  switch (mode) {
    case 'cultural':
    case 'spiritual':
      return [
        `node["historic"]${nameFilter}`,
        `node["tourism"="museum"]${nameFilter}`,
        `node["tourism"="attraction"]${nameFilter}`,
        `node["heritage"]${nameFilter}`,
        `node["amenity"="place_of_worship"]${nameFilter}`,
      ];
    case 'foodie':
      return [
        `node["amenity"="restaurant"]${nameFilter}`,
        `node["amenity"="cafe"]${nameFilter}`,
      ];
    case 'coastal':
      return [
        `node["natural"="beach"]${nameFilter}`,
        `node["tourism"="attraction"]${nameFilter}`,
      ];
    case 'wildlife':
      return [
        `way["boundary"="national_park"]`,
        `way["leisure"="nature_reserve"]`,
        `node["tourism"="zoo"]${nameFilter}`,
        `node["natural"="peak"]${nameFilter}`,
      ];
    case 'full_adventure':
    case 'adventure':
    default:
      return [
        `node["waterway"="waterfall"]`,
        `node["tourism"="viewpoint"]${nameFilter}`,
        `node["historic"="ruins"]${nameFilter}`,
        `node["natural"="peak"]${nameFilter}`,
        `node["natural"="cave_entrance"]`,
        `node["tourism"="attraction"]${nameFilter}`,
      ];
  }
}

/**
 * Build an Overpass QL query using per-point "around" radius filters.
 * This is MUCH lighter than a single bounding-box query for long routes
 * because it only searches small circles around each sampled waypoint.
 *
 * @param {Array} sampledPoints - The sampled route points
 * @param {string} mode - The route mode (cultural, foodie, etc.)
 * @param {number} radiusM - Search radius in meters around each point (default 15km)
 * @param {boolean} simplified - If true, use fewer tag filters for a lighter query
 */
function buildOverpassQuery(sampledPoints, mode, radiusM = 15000, simplified = false) {
  // Build the coordinate list for the around filter: lat,lng,lat,lng,...
  const coordList = sampledPoints.map(pt => `${pt.lat},${pt.lng}`).join(',');
  const aroundFilter = `(around:${radiusM},${coordList})`;

  const tagFilters = getOverpassTagFilters(mode);

  // In simplified mode, use only the first 2 most important filters
  const filters = simplified ? tagFilters.slice(0, 2) : tagFilters;

  let query = `[out:json][timeout:20];\n(\n`;
  for (const filter of filters) {
    query += `  ${filter}${aroundFilter};\n`;
  }
  query += `);\nout center 50;\n`;
  return query;
}

function parseOsmElement(el) {
  const tags = el.tags || {};
  let name = tags.name || tags['name:en'] || null;
  let type = 'scenic';
  let reason = 'An interesting spot to check out.';

  if (tags.tourism === 'viewpoint') {
    type = 'viewpoint';
    reason = 'A beautiful scenic viewpoint.';
    if (!name) name = 'Scenic Viewpoint';
  } else if (tags.waterway === 'waterfall') {
    type = 'waterfall';
    reason = 'A majestic waterfall.';
    if (!name) name = 'Hidden Waterfall';
  } else if (tags.waterway === 'dam') {
    type = 'dam';
    reason = 'An impressive dam structure.';
    if (!name) name = 'Scenic Dam';
  } else if (tags.natural === 'water') {
    type = 'lake';
    reason = 'A beautiful body of water.';
    if (!name) name = 'Tranquil Lake';
  } else if (tags.natural === 'cave_entrance') {
    type = 'cave';
    reason = 'A fascinating cave entrance.';
    if (!name) name = 'Mysterious Cave';
  } else if (tags.natural === 'peak') {
    type = 'mountain_pass';
    reason = tags.ele ? `A peak at ${tags.ele}m elevation.` : 'A high mountain peak.';
    if (!name) name = 'Mountain Peak';
  } else if (tags.tourism === 'attraction') {
    type = 'attraction';
    reason = 'A notable local tourist attraction.';
    if (!name) name = 'Local Attraction';
  } else if (tags.tourism === 'museum' || tags.tourism === 'gallery') {
    type = 'museum';
    reason = 'A fascinating museum.';
    if (!name) name = 'Local Museum';
  } else if (tags.historic === 'fort' || tags.historic === 'castle') {
    type = 'fort';
    reason = 'A historic fort worth exploring.';
    if (!name) name = 'Historic Fort';
  } else if (tags.historic === 'palace') {
    type = 'palace';
    reason = 'A magnificent palace.';
    if (!name) name = 'Royal Palace';
  } else if (tags.historic === 'monument' || tags.historic === 'memorial') {
    type = 'monument';
    reason = 'A remarkable historical monument.';
    if (!name) name = 'Historical Monument';
  } else if (tags.historic === 'archaeological_site') {
    type = 'monument';
    reason = 'An ancient archaeological site.';
    if (!name) name = 'Archaeological Site';
  } else if (tags.historic === 'ruins') {
    type = 'heritage';
    reason = 'Historical ruins to explore.';
    if (!name) name = 'Ancient Ruins';
  } else if (tags.historic) {
    type = 'heritage';
    reason = 'A historically significant place.';
    if (!name) name = 'Heritage Site';
  } else if (tags.heritage) {
    type = 'heritage';
    reason = 'A designated heritage site.';
    if (!name) name = 'Heritage Site';
  } else if (tags.amenity === 'restaurant') {
    type = 'restaurant';
    reason = tags.cuisine
      ? `Known for ${tags.cuisine.replace(/;/g, ', ')} cuisine.`
      : 'A highly rated local restaurant.';
    if (!name) name = 'Local Restaurant';
  } else if (tags.amenity === 'cafe') {
    type = 'cafe';
    reason = 'A great place to grab coffee and snacks.';
    if (!name) name = 'Cozy Cafe';
  } else if (tags.amenity === 'fast_food') {
    type = 'restaurant';
    reason = 'Quick eats available here.';
    if (!name) name = 'Quick Bites';
  } else if (tags.shop === 'bakery') {
    type = 'bakery';
    reason = 'Freshly baked goods available here.';
    if (!name) name = 'Local Bakery';
  } else if (tags.natural === 'beach') {
    type = 'beach';
    reason = 'A beautiful coastal spot.';
    if (!name) name = 'Scenic Beach';
  } else if (tags.leisure === 'marina') {
    type = 'marina';
    reason = 'A lovely marina with boats.';
    if (!name) name = 'Local Marina';
  } else if (tags.amenity === 'place_of_worship') {
    type = 'worship';
    const religion = tags.religion || '';
    if (religion === 'hindu') reason = 'A sacred Hindu temple.';
    else if (religion === 'christian') reason = 'A historic church.';
    else if (religion === 'muslim') reason = 'A beautiful mosque.';
    else if (religion === 'sikh') reason = 'A revered Gurudwara.';
    else if (religion === 'buddhist') reason = 'A serene Buddhist monastery.';
    else if (religion === 'jain') reason = 'A Jain temple.';
    else reason = 'A peaceful spiritual center.';
    if (!name) name = 'Spiritual Center';
  } else if (tags.boundary === 'national_park' || tags.leisure === 'nature_reserve') {
    type = 'national_park';
    reason = 'A protected nature reserve.';
    if (!name) name = 'Nature Reserve';
  } else if (tags.tourism === 'zoo') {
    type = 'zoo';
    reason = 'A wildlife sanctuary or zoo.';
    if (!name) name = 'Wildlife Sanctuary';
  } else if (tags.ford === 'yes') {
    type = 'water_crossing';
    reason = 'An exciting water crossing / river ford.';
    if (!name) name = 'River Ford';
  }

  const lat = el.lat || (el.center && el.center.lat);
  const lng = el.lon || (el.center && el.center.lon);

  let notability = 0;
  if (tags.name) notability += 2;
  if (tags['name:en']) notability += 1;
  if (tags.wikidata) notability += 3;
  if (tags.wikipedia) notability += 3;
  if (tags.heritage) notability += 2;
  if (tags.tourism === 'attraction') notability += 2;
  if (tags.historic) notability += 1;

  return { lat, lng, name, reason, type, notability, source: 'osm' };
}

async function queryOverpass(query, timeoutMs = 25000) {
  let lastError = null;
  for (const mirror of OVERPASS_MIRRORS) {
    try {
      const response = await axios.post(
        mirror,
        `data=${encodeURIComponent(query)}`,
        {
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            Accept: 'application/json',
            'User-Agent': 'TrailMateApp/1.0',
          },
          timeout: timeoutMs,
        }
      );
      console.log(`[SmartRoute] Overpass mirror ${mirror} succeeded with ${response.data?.elements?.length || 0} elements`);
      return response.data;
    } catch (err) {
      const status = err.response?.status || 'timeout';
      console.log(`[SmartRoute] Overpass mirror ${mirror} failed (${status}), trying next...`);
      lastError = err;
    }
  }
  throw lastError || new Error('All Overpass mirrors failed');
}

const ROUTE_CHARACTERS = {
  cultural: 'A heritage trail through historical monuments, forts, temples, and museums.',
  foodie: 'A foodie road trip with the best local eateries, cafes, and bakeries.',
  coastal: 'A scenic coastal route with beaches, marinas, and ocean views.',
  spiritual: 'A spiritual journey through temples, churches, mosques, and sacred sites.',
  wildlife: 'A nature safari through national parks, reserves, and wildlife sanctuaries.',
  full_adventure: 'A hardcore off-road adventure with river crossings, peaks, and jungle trails.',
  adventure: 'A scenic adventure route with viewpoints, waterfalls, and hidden gems.',
};

/**
 * Generate waypoints exclusively along the real polyline corridor.
 */
async function generateAdventureWaypoints(originLat, originLng, destLat, destLng, mode, steps) {
  // 1. Sample the route steps every ~30km
  const sampledPoints = [];
  let accumulatedDist = 0;
  let lastPoint = { lat: originLat, lng: originLng };
  sampledPoints.push(lastPoint);

  if (steps && steps.length > 0) {
    for (const step of steps) {
      if (!step.start_location) continue;
      const pt = { lat: step.start_location.lat, lng: step.start_location.lng };
      const dist = haversineKm(lastPoint.lat, lastPoint.lng, pt.lat, pt.lng);
      accumulatedDist += dist;
      
      if (accumulatedDist >= 30) {
        sampledPoints.push(pt);
        accumulatedDist = 0;
        lastPoint = pt;
      }
    }
  }
  sampledPoints.push({ lat: destLat, lng: destLng });

  console.log(`[SmartRoute] Corridor sampled into ${sampledPoints.length} points.`);

  // 2. Fetch from APIs — use multiple sources with Ola Maps as primary
  
  // Overpass is best-effort and non-blocking (don't let it slow things down)
  const overpassFetch = async () => {
    try {
      const query = buildOverpassQuery(sampledPoints, mode);
      return await queryOverpass(query, 15000);
    } catch (e) {
      console.log(`[SmartRoute] Overpass query failed, skipping (have other sources)`);
      return { elements: [] };
    }
  };

  // Fire all sources in parallel — Ola Maps + Wikipedia are the reliable ones
  const [olaPlaces, wikiPlaces, otmPlaces, osmData] = await Promise.all([
    fetchOlaNearbyPlaces(sampledPoints, mode),
    fetchWikipediaPlaces(sampledPoints),
    fetchOpenTripMapPlaces(originLat, originLng, destLat, destLng, mode),
    overpassFetch()
  ]);

  const elements = osmData?.elements || [];
  let parsedOsm = elements.map(parseOsmElement).filter((wp) => wp.lat && wp.lng);

  // Filter OSM POIs to only keep those within 15km of ANY sampled point
  parsedOsm = parsedOsm.filter(wp => {
    return sampledPoints.some(pt => haversineKm(wp.lat, wp.lng, pt.lat, pt.lng) <= 15);
  });

  console.log(`[SmartRoute] Sources: Ola=${olaPlaces.length}, Wiki=${wikiPlaces.length}, OTM=${otmPlaces.length}, OSM=${parsedOsm.length}`);

  // Ola Maps places are highest priority, then Wikipedia, then others
  let allPlaces = [...olaPlaces, ...wikiPlaces, ...otmPlaces, ...parsedOsm];

  if (allPlaces.length === 0) {
    return { waypoints: [], routeCharacter: ROUTE_CHARACTERS[mode] || 'A scenic route.' };
  }

  // 3. Boost notability for famous landmarks and filter junk
  for (const place of allPlaces) {
    const nameLower = (place.name || '').toLowerCase();
    
    // Filter out non-tourist Wikipedia entries (administrative entities)
    if (place.source === 'wikipedia') {
      const junkPatterns = ['constituency', 'district', 'taluk', 'block', 'mandal', 
        'tehsil', 'panchayat', 'municipality', 'corporation', 'lok sabha', 
        'vidhan sabha', 'assembly', 'railway station', 'bus stand', 'junction'];
      if (junkPatterns.some(p => nameLower.includes(p))) {
        place.notability = -1; // Will be filtered out
        continue;
      }
    }
    
    // Boost landmark keywords - these are what tourists actually want to visit
    const landmarkBoosts = [
      { patterns: ['fort', 'killa', 'kote', 'durga', 'garh'], boost: 6 },
      { patterns: ['gumbaz', 'gumbad', 'tomb', 'mausoleum', 'maqbara'], boost: 6 },
      { patterns: ['palace', 'mahal', 'rajwada'], boost: 5 },
      { patterns: ['temple', 'mandir', 'devasthana', 'kovil', 'gudi'], boost: 5 },
      { patterns: ['mosque', 'masjid', 'dargah', 'church', 'basilica', 'cathedral'], boost: 5 },
      { patterns: ['museum', 'gallery'], boost: 4 },
      { patterns: ['falls', 'waterfall', 'jog', 'abbey'], boost: 4 },
      { patterns: ['lake', 'dam', 'reservoir', 'sagar', 'kere'], boost: 3 },
      { patterns: ['national park', 'wildlife', 'sanctuary', 'reserve'], boost: 4 },
      { patterns: ['caves', 'cave', 'guha', 'leni'], boost: 4 },
      { patterns: ['pillar', 'stambha', 'monument', 'memorial', 'statue'], boost: 3 },
      { patterns: ['heritage', 'unesco', 'world heritage'], boost: 6 },
    ];
    
    for (const { patterns, boost } of landmarkBoosts) {
      if (patterns.some(p => nameLower.includes(p))) {
        place.notability += boost;
        break; // Only apply the highest matching boost
      }
    }
  }
  
  // Remove filtered entries and sort by notability
  allPlaces = allPlaces.filter(p => p.notability >= 0);
  allPlaces.sort((a, b) => b.notability - a.notability);

  const waypoints = [];
  const seen = new Set();
  
  for (const wp of allPlaces) {
    const normalizedName = (wp.name || 'anon').toLowerCase().replace(/[^a-z0-9]/g, '');
    const key = `${normalizedName}-${Math.round(wp.lat)}-${Math.round(wp.lng)}`;

    let tooClose = false;
    for (const existing of waypoints) {
      const dist = haversineKm(wp.lat, wp.lng, existing.lat, existing.lng);
      
      // 2km physical deduplication — allows nearby-but-distinct landmarks
      if (dist < 2) {
        tooClose = true;
        break;
      }
      
      // Name deduplication within 30km
      const existingNameNorm = (existing.name || '').toLowerCase().replace(/[^a-z0-9]/g, '');
      if (dist < 30 && (existingNameNorm === normalizedName || existingNameNorm.includes(normalizedName) || normalizedName.includes(existingNameNorm))) {
          tooClose = true;
          break;
      }
    }
    if (tooClose) continue;

    seen.add(key);

    waypoints.push({
      lat: wp.lat,
      lng: wp.lng,
      name: wp.name || 'Scenic Spot',
      reason: wp.reason,
      type: wp.type,
    });

    if (waypoints.length >= 25) break;
  }

  return { waypoints, routeCharacter: ROUTE_CHARACTERS[mode] || 'A scenic route.' };
}

router.post('/smart-route', async (req, res) => {
  try {
    const { origin, destination, mode = 'highway', transportMode } = req.body;
    if (!origin || !destination) {
      return res.status(400).json({ error: 'Origin and destination are required' });
    }

    const [originLat, originLng] = origin.split(',').map(Number);
    const [destLat, destLng] = destination.split(',').map(Number);

    const params = { origin, destination, api_key: getOlaApiKey(), steps: true };
    if (transportMode) params.mode = transportMode;

    // STEP 1: Fetch baseline route from Ola Maps to get the exact road polyline
    const initialRouteResponse = await axios.post(`${OLA_BASE_URL}/routing/v1/directions`, null, {
      params,
      headers: { 'X-Request-Id': `trailmate-base-${Date.now()}` },
      timeout: 15000,
    });

    if (mode === 'highway') {
      return res.json({
        ...initialRouteResponse.data,
        aiWaypoints: [],
        mode: 'highway',
        routeCharacter: 'Direct highway route — fastest path to your destination.',
      });
    }

    console.log(`[SmartRoute] Fetching AI waypoints along corridor for ${mode}: ${origin} → ${destination}`);

    const steps = initialRouteResponse.data.routes?.[0]?.legs?.[0]?.steps || [];
    const aiResult = await generateAdventureWaypoints(originLat, originLng, destLat, destLng, mode, steps);

    console.log(`[SmartRoute] Found ${aiResult.waypoints.length} waypoints for ${mode}`);

    // STEP 2: Make final call to Ola Maps with the generated waypoints
    const waypointsStr = aiResult.waypoints.map((wp) => `${wp.lat},${wp.lng}`).join('|');
    
    let url = `${OLA_BASE_URL}/routing/v1/directions?origin=${origin}&destination=${destination}&api_key=${getOlaApiKey()}&steps=true`;
    if (transportMode) url += `&mode=${transportMode}`;
    if (waypointsStr) url += `&waypoints=${waypointsStr}`;

    const finalResponse = await axios.post(url, null, {
      headers: { 'X-Request-Id': `trailmate-final-${Date.now()}` },
      timeout: 15000,
    });

    return res.json({
      ...finalResponse.data,
      aiWaypoints: aiResult.waypoints,
      mode,
      routeCharacter: aiResult.routeCharacter,
    });
  } catch (error) {
    console.error('[SmartRoute] Error:', error.response?.data?.error || error.message);
    try {
      const { origin, destination, transportMode } = req.body;
      let fallbackUrl = `${OLA_BASE_URL}/routing/v1/directions?origin=${origin}&destination=${destination}&api_key=${getOlaApiKey()}&steps=true`;
      if (transportMode) fallbackUrl += `&mode=${transportMode}`;

      const fallback = await axios.post(fallbackUrl, null, { timeout: 15000 });
      return res.json({
        ...fallback.data,
        aiWaypoints: [],
        mode: 'highway',
        routeCharacter: 'Direct route (fallback mode).',
      });
    } catch (fallbackError) {
      return res.status(500).json({ error: 'Failed to generate any route.' });
    }
  }
});

module.exports = router;
