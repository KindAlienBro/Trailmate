const Group = require('../models/Group');
const axios = require('axios');

const OLA_BASE_URL = 'https://api.olamaps.io';
const getApiKey = () => process.env.OLA_MAPS_API_KEY;

// Track suggestion cooldowns per group per socket
const suggestionCooldowns = new Map();

/**
 * Smart Suggestions Engine — Proactively suggests POIs during navigation.
 *
 * Triggers:
 *   - Every 15 minutes or 50 km of driving
 *   - When leader stops for > 3 minutes
 *   - When approaching an AI waypoint (adventure mode)
 *
 * Events:
 *   suggestion:check   — Client asks for suggestions
 *   suggestion:show    — Server pushes a suggestion to the group
 */
function setupSmartSuggestions(io) {
  io.on('connection', (socket) => {

    /**
     * Client periodically sends check requests with driving context.
     * Data: { groupId, lat, lng, elapsedMinutes, distanceTraveled, isStopped }
     */
    socket.on('suggestion:check', async (data) => {
      try {
        const { groupId, lat, lng, elapsedMinutes, distanceTraveled, isStopped } = data;
        if (!groupId || lat == null || lng == null) return;

        // Cooldown: minimum 5 minutes between suggestions per group
        const cooldownKey = `${groupId}:${socket.userId}`;
        const lastSuggestionTime = suggestionCooldowns.get(cooldownKey) || 0;
        const now = Date.now();
        if (now - lastSuggestionTime < 5 * 60 * 1000) return; // 5 min cooldown

        const group = await Group.findById(groupId);
        if (!group || group.status !== 'active') return;

        // Only leader gets smart suggestions to avoid spam
        if (!group.isLeader(socket.userId)) return;

        // Determine what to suggest based on context
        const suggestions = [];

        // 1. Fuel suggestion — always relevant
        const fuelPlaces = await searchNearby(lat, lng, 'gas_station', 5000);
        if (fuelPlaces.length > 0) {
          const nearest = fuelPlaces[0];
          suggestions.push({
            type: 'fuel',
            name: nearest.name,
            lat: nearest.lat,
            lng: nearest.lng,
            distance: nearest.distance,
            reason: '⛽ Fuel station nearby',
            icon: 'gas_station',
            priority: 1,
          });
        }

        // 2. Proactive Route Stops (Restaurants, Shops)
        const foodPlaces = await searchNearby(lat, lng, 'restaurant', 5000);
        if (foodPlaces.length > 0) {
          const nearest = foodPlaces[0];
          suggestions.push({
            type: 'proactive_stop',
            name: nearest.name,
            lat: nearest.lat,
            lng: nearest.lng,
            distance: nearest.distance,
            reason: `🍔 Stop ahead: ${nearest.name}`,
            icon: 'restaurant',
            priority: 2,
          });
        }

        // 3. AI Waypoint approaching (adventure mode)
        if (group.route.aiWaypoints && group.route.aiWaypoints.length > 0) {
          for (const wp of group.route.aiWaypoints) {
            const dist = haversineDistance(lat, lng, wp.lat, wp.lng);
            if (dist < 5000 && dist > 500) { // Between 500m and 5km
              suggestions.push({
                type: 'ai_waypoint',
                name: wp.name,
                lat: wp.lat,
                lng: wp.lng,
                distance: Math.round(dist),
                reason: `✨ ${wp.reason || 'Adventure stop ahead!'}`,
                icon: wp.type || 'scenic',
                priority: 3,
              });
              break; // Only one AI waypoint suggestion at a time
            }
          }
        }

        // 4. Stopped suggestions — when leader stops for a while
        if (isStopped) {
          const nearbyOptions = [];
          const types = ['restaurant', 'gas_station', 'hospital'];
          for (const type of types) {
            const places = await searchNearby(lat, lng, type, 3000);
            if (places.length > 0) {
              nearbyOptions.push({
                type: 'stopped_suggestion',
                name: places[0].name,
                lat: places[0].lat,
                lng: places[0].lng,
                distance: places[0].distance,
                reason: `📍 Nearby: ${places[0].name}`,
                icon: type,
                priority: 4,
              });
            }
          }
          suggestions.push(...nearbyOptions.slice(0, 2));
        }

        // Send the best suggestion (highest priority = lowest number)
        if (suggestions.length > 0) {
          suggestions.sort((a, b) => a.priority - b.priority);
          const best = suggestions[0];

          suggestionCooldowns.set(cooldownKey, now);

          socket.emit('suggestion:show', {
            suggestion: best,
            allSuggestions: suggestions.slice(0, 3), // Send top 3
            timestamp: now,
          });

          console.log(`[SmartSuggestions] Sent ${best.type} suggestion to ${socket.user.name}: ${best.name}`);
        }
      } catch (error) {
        console.error('[SmartSuggestions] Error:', error.message);
      }
    });
  });
}

/**
 * Search for nearby places using Ola Maps API.
 */
async function searchNearby(lat, lng, type, radius = 5000) {
  try {
    const response = await axios.get(`${OLA_BASE_URL}/places/v1/nearbysearch`, {
      params: {
        layers: 'venue',
        location: `${lat},${lng}`,
        types: type,
        radius,
        api_key: getApiKey(),
      },
      timeout: 10000,
    });

    const predictions = response.data?.predictions || [];
    return predictions.slice(0, 3).map(p => {
      const geometry = p.geometry;
      const location = geometry?.location;
      return {
        name: p.structured_formatting?.main_text || p.description || p.name || 'Unknown',
        lat: location?.lat,
        lng: location?.lng,
        distance: geometry?.distance || 0,
      };
    }).filter(p => p.lat != null && p.lng != null);
  } catch {
    return [];
  }
}

/**
 * Haversine distance between two GPS coordinates in meters.
 */
function haversineDistance(lat1, lon1, lat2, lon2) {
  const R = 6371000;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

function toRad(deg) {
  return deg * (Math.PI / 180);
}

module.exports = { setupSmartSuggestions };
