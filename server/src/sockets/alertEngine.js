const Group = require('../models/Group');

/**
 * Alert Engine — Detects route deviations, separations, stalls, and SOS.
 *
 * Events emitted to group room:
 *   alert:deviation    — Member is too far from the route polyline
 *   alert:separation   — Member is too far behind the leader
 *   alert:stall        — Member hasn't moved for too long
 *   sos:triggered      — A member triggered an emergency
 *   sos:acknowledged   — Leader acknowledged the SOS
 *   sos:cancelled      — SOS was cancelled
 */
function setupAlertEngine(io) {
  io.on('connection', (socket) => {

    /**
     * Check if a member has deviated from the route.
     * Called periodically or on each location update.
     * Uses point-to-polyline distance calculation.
     */
    socket.on('alert:checkDeviation', async (data) => {
      try {
        const { groupId, lat, lng } = data;
        if (!groupId || lat == null || lng == null) return;

        const group = await Group.findById(groupId);
        if (!group || group.status !== 'active') return;
        if (!group.route.polylinePoints || group.route.polylinePoints.length < 2) return;

        const threshold = group.settings.deviationThresholdMeters;
        const minDistance = getMinDistanceToPolyline(
          lat, lng,
          group.route.polylinePoints
        );

        const member = group.getMember(socket.userId);
        if (!member) return;

        if (minDistance > threshold) {
          // Member has deviated
          if (member.status !== 'deviated' && member.status !== 'sos') {
            member.status = 'deviated';
            await group.save();

            const roomName = `group:${groupId}`;
            io.to(roomName).emit('alert:deviation', {
              userId: socket.userId,
              name: socket.user.name,
              lat,
              lng,
              distanceFromRoute: Math.round(minDistance),
              message: `${socket.user.name} has deviated from the route (${Math.round(minDistance)}m away)`,
              timestamp: Date.now(),
            });
          }
        } else {
          // Back on route
          if (member.status === 'deviated') {
            member.status = 'on-route';
            await group.save();

            io.to(`group:${groupId}`).emit('alert:backOnRoute', {
              userId: socket.userId,
              name: socket.user.name,
              message: `${socket.user.name} is back on the route`,
              timestamp: Date.now(),
            });
          }
        }
      } catch (error) {
        console.error('[AlertEngine] Deviation check error:', error.message);
      }
    });

    /**
     * Check separation from group leader.
     */
    socket.on('alert:checkSeparation', async (data) => {
      try {
        const { groupId, lat, lng } = data;
        if (!groupId || lat == null || lng == null) return;

        const group = await Group.findById(groupId);
        if (!group || group.status !== 'active') return;

        const leader = group.members.find(m => m.role === 'leader');
        if (!leader || !leader.lastLocation?.lat) return;
        if (socket.userId === leader.userId.toString()) return; // Don't alert the leader about themselves

        const threshold = group.settings.separationThresholdMeters;
        const distance = haversineDistance(
          lat, lng,
          leader.lastLocation.lat, leader.lastLocation.lng
        );

        const member = group.getMember(socket.userId);
        if (!member) return;

        if (distance > threshold) {
          const now = Date.now();
          const cooldownPeriod = 5 * 60 * 1000; // 5 minutes
          
          if (!member.lastSeparationAlertAt || (now - member.lastSeparationAlertAt.getTime() > cooldownPeriod)) {
            member.lastSeparationAlertAt = new Date(now);
            await group.save();

            io.to(`group:${groupId}`).emit('alert:separation', {
              userId: socket.userId,
              name: socket.user.name,
              lat,
              lng,
              distanceFromLeader: Math.round(distance),
              message: `${socket.user.name} is ${(distance / 1000).toFixed(1)}km behind the group`,
              timestamp: now,
            });
          }
        } else {
          // If they catch back up, reset the cooldown so we alert again if they fall behind
          if (member.lastSeparationAlertAt) {
            member.lastSeparationAlertAt = null;
            await group.save();
          }
        }
      } catch (error) {
        console.error('[AlertEngine] Separation check error:', error.message);
      }
    });

    /**
     * SOS — Emergency triggered by a member.
     * Broadcasts to the entire group immediately.
     */
    socket.on('sos:trigger', async (data) => {
      try {
        const { groupId, lat, lng, message } = data;
        if (!groupId) return;

        const group = await Group.findById(groupId);
        if (!group || !group.isMember(socket.userId)) return;

        // Update member status to SOS
        const member = group.getMember(socket.userId);
        if (member) {
          member.status = 'sos';
          if (lat != null && lng != null) {
            member.lastLocation = {
              ...member.lastLocation,
              lat,
              lng,
              updatedAt: new Date(),
            };
          }
          await group.save();
        }

        // Broadcast SOS to all group members
        io.to(`group:${groupId}`).emit('sos:triggered', {
          userId: socket.userId,
          name: socket.user.name,
          lat: lat || member?.lastLocation?.lat,
          lng: lng || member?.lastLocation?.lng,
          message: message || `${socket.user.name} needs help!`,
          timestamp: Date.now(),
        });

        console.log(`[AlertEngine] 🆘 SOS triggered by ${socket.user.name} in group ${groupId}`);
      } catch (error) {
        console.error('[AlertEngine] SOS trigger error:', error.message);
      }
    });

    /**
     * SOS — Leader acknowledges the emergency.
     */
    socket.on('sos:acknowledge', async (data) => {
      try {
        const { groupId, targetUserId } = data;
        if (!groupId || !targetUserId) return;

        const group = await Group.findById(groupId);
        if (!group || !group.isLeader(socket.userId)) return;

        io.to(`group:${groupId}`).emit('sos:acknowledged', {
          acknowledgedBy: socket.user.name,
          targetUserId,
          message: `Leader ${socket.user.name} acknowledged the emergency`,
          timestamp: Date.now(),
        });
      } catch (error) {
        console.error('[AlertEngine] SOS acknowledge error:', error.message);
      }
    });

    /**
     * SOS — Cancel the emergency.
     */
    socket.on('sos:cancel', async (data) => {
      try {
        const { groupId } = data;
        if (!groupId) return;

        const group = await Group.findById(groupId);
        if (!group || !group.isMember(socket.userId)) return;

        const member = group.getMember(socket.userId);
        if (member && member.status === 'sos') {
          member.status = 'on-route';
          await group.save();
        }

        io.to(`group:${groupId}`).emit('sos:cancelled', {
          userId: socket.userId,
          name: socket.user.name,
          message: `${socket.user.name} cancelled the emergency`,
          timestamp: Date.now(),
        });
      } catch (error) {
        console.error('[AlertEngine] SOS cancel error:', error.message);
      }
    });
    /**
     * Regroup — Leader requests group to regroup.
     */
    socket.on('alert:triggerRegroup', async (data) => {
      try {
        const { groupId, lat, lng } = data;
        if (!groupId) return;

        const group = await Group.findById(groupId);
        if (!group || !group.isLeader(socket.userId)) return;

        io.to(`group:${groupId}`).emit('alert:regroup', {
          userId: socket.userId,
          name: socket.user.name,
          lat,
          lng,
          message: `${socket.user.name} has requested a regroup here.`,
          timestamp: Date.now(),
        });
      } catch (error) {
        console.error('[AlertEngine] Trigger regroup error:', error.message);
      }
    });

    /**
     * Request Stop — Member requests a stop with a reason.
     */
    socket.on('alert:requestStop', async (data) => {
      try {
        const { groupId, lat, lng, reason } = data;
        if (!groupId) return;

        const group = await Group.findById(groupId);
        if (!group || !group.isMember(socket.userId)) return;

        io.to(`group:${groupId}`).emit('alert:stopRequest', {
          userId: socket.userId,
          name: socket.user.name,
          lat,
          lng,
          message: `${socket.user.name} needs to stop for: ${reason}`,
          reason,
          timestamp: Date.now(),
        });
      } catch (error) {
        console.error('[AlertEngine] Request stop error:', error.message);
      }
    });
  });
}

// ==================== Helper: Haversine Distance ====================

/**
 * Calculate distance between two GPS coordinates in meters.
 */
function haversineDistance(lat1, lon1, lat2, lon2) {
  const R = 6371000; // Earth's radius in meters
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

/**
 * Find the minimum distance from a point to a polyline (array of {lat, lng}).
 */
function getMinDistanceToPolyline(lat, lng, polylinePoints) {
  let minDist = Infinity;
  for (let i = 0; i < polylinePoints.length - 1; i++) {
    const dist = pointToSegmentDistance(
      lat, lng,
      polylinePoints[i].lat, polylinePoints[i].lng,
      polylinePoints[i + 1].lat, polylinePoints[i + 1].lng
    );
    if (dist < minDist) minDist = dist;
  }
  return minDist;
}

/**
 * Distance from a point to a line segment (all in lat/lng).
 */
function pointToSegmentDistance(pLat, pLng, aLat, aLng, bLat, bLng) {
  const ab = { lat: bLat - aLat, lng: bLng - aLng };
  const ap = { lat: pLat - aLat, lng: pLng - aLng };

  const abLenSq = ab.lat * ab.lat + ab.lng * ab.lng;
  if (abLenSq === 0) return haversineDistance(pLat, pLng, aLat, aLng);

  let t = (ap.lat * ab.lat + ap.lng * ab.lng) / abLenSq;
  t = Math.max(0, Math.min(1, t));

  const closestLat = aLat + t * ab.lat;
  const closestLng = aLng + t * ab.lng;

  return haversineDistance(pLat, pLng, closestLat, closestLng);
}

module.exports = { setupAlertEngine };
