const Group = require('../models/Group');

/**
 * Route Sync — Broadcasts route updates to all group members.
 *
 * When the leader modifies the route (adds/removes waypoints, changes
 * destination), the update is pushed to all connected members in real-time.
 *
 * Events:
 *   route:update    — Leader pushes a route change
 *   route:updated   — Server broadcasts the new route to all members
 */
function setupRouteSync(io) {
  io.on('connection', (socket) => {

    /**
     * Leader updates the route and broadcasts to all members.
     * Data: { groupId, origin, destination, waypoints, polyline, polylinePoints, distanceMeters, durationSeconds }
     */
    socket.on('route:update', async (data) => {
      try {
        const { groupId, origin, destination, waypoints, polyline, polylinePoints, distanceMeters, durationSeconds } = data;
        if (!groupId) return;

        const group = await Group.findById(groupId);
        if (!group) return;

        // Only the leader can update the route
        if (!group.isLeader(socket.userId)) {
          socket.emit('error', { message: 'Only the leader can update the route' });
          return;
        }

        // Update route in database
        if (origin) group.route.origin = origin;
        if (destination) group.route.destination = destination;
        if (waypoints !== undefined) group.route.waypoints = waypoints;
        if (polyline) group.route.polyline = polyline;
        if (polylinePoints) group.route.polylinePoints = polylinePoints;
        if (distanceMeters !== undefined) group.route.distanceMeters = distanceMeters;
        if (durationSeconds !== undefined) group.route.durationSeconds = durationSeconds;

        await group.save();

        // Broadcast the updated route to all group members
        io.to(`group:${groupId}`).emit('route:updated', {
          route: group.route,
          updatedBy: socket.user.name,
          message: `Route updated by ${socket.user.name}`,
          timestamp: Date.now(),
        });

        console.log(`[RouteSync] Route updated by ${socket.user.name} for group ${groupId}`);
      } catch (error) {
        console.error('[RouteSync] Route update error:', error.message);
      }
    });

    /**
     * Leader starts the trip — notifies all members.
     */
    socket.on('trip:start', async (data) => {
      try {
        const { groupId } = data;
        if (!groupId) return;

        const group = await Group.findById(groupId);
        if (!group || !group.isLeader(socket.userId)) return;

        group.status = 'active';
        // Set all members to 'on-route' status
        group.members.forEach(m => {
          m.status = 'on-route';
        });
        await group.save();

        io.to(`group:${groupId}`).emit('trip:started', {
          message: `Trip started by ${socket.user.name}!`,
          route: group.route,
          timestamp: Date.now(),
        });

        console.log(`[RouteSync] Trip started by ${socket.user.name} for group ${groupId}`);
      } catch (error) {
        console.error('[RouteSync] Trip start error:', error.message);
      }
    });

    /**
     * Leader ends the trip — notifies all members.
     */
    socket.on('trip:end', async (data) => {
      try {
        const { groupId } = data;
        if (!groupId) return;

        const group = await Group.findById(groupId);
        if (!group || !group.isLeader(socket.userId)) return;

        group.status = 'completed';
        group.members.forEach(m => {
          m.status = 'waiting';
        });
        await group.save();

        io.to(`group:${groupId}`).emit('trip:ended', {
          message: 'Trip completed! Great journey everyone! 🎉',
          timestamp: Date.now(),
        });

        console.log(`[RouteSync] Trip ended by ${socket.user.name} for group ${groupId}`);
      } catch (error) {
        console.error('[RouteSync] Trip end error:', error.message);
      }
    });

    /**
     * Member joined notification — broadcast when someone joins via REST API
     * The REST route can emit this via the io instance.
     */
    socket.on('member:joined', async (data) => {
      try {
        const { groupId } = data;
        if (!groupId) return;

        io.to(`group:${groupId}`).emit('member:joined', {
          userId: socket.userId,
          name: socket.user.name,
          avatar: socket.user.avatar,
          message: `${socket.user.name} joined the group`,
          timestamp: Date.now(),
        });
      } catch (error) {
        console.error('[RouteSync] Member joined error:', error.message);
      }
    });
  });
}

module.exports = { setupRouteSync };
