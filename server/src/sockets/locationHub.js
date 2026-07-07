const Group = require('../models/Group');

/**
 * Location Hub — Real-time location broadcasting for group members.
 *
 * Events:
 *   location:update    — Member sends their GPS position
 *   location:subscribe — Member joins their group's location room
 *   location:members   — Server broadcasts all members' positions
 */
function setupLocationHub(io) {
  io.on('connection', (socket) => {
    console.log(`[LocationHub] User connected: ${socket.user.name} (${socket.userId})`);

    /**
     * Subscribe to a group's location updates.
     * The user joins a Socket.IO room named "group:<groupId>".
     */
    socket.on('location:subscribe', async (data) => {
      try {
        const { groupId } = data;
        if (!groupId) return;

        const group = await Group.findById(groupId);
        if (!group || !group.isMember(socket.userId)) {
          socket.emit('error', { message: 'Not a member of this group' });
          return;
        }

        const roomName = `group:${groupId}`;
        socket.join(roomName);
        socket.groupId = groupId;

        console.log(`[LocationHub] ${socket.user.name} subscribed to ${roomName}`);

        // Send current member positions to the newly joined user
        const memberLocations = group.members.map(m => ({
          userId: m.userId.toString(),
          name: m.name,
          avatar: m.avatar,
          role: m.role,
          status: m.status,
          location: m.lastLocation,
        }));

        socket.emit('location:members', { members: memberLocations });
      } catch (error) {
        console.error('[LocationHub] Subscribe error:', error.message);
      }
    });

    /**
     * Receive a location update from a member and broadcast to the group.
     * Data: { groupId, lat, lng, speed, heading, timestamp }
     */
    socket.on('location:update', async (data) => {
      try {
        const { groupId, lat, lng, speed, heading } = data;
        if (!groupId || lat == null || lng == null) return;

        const group = await Group.findById(groupId);
        if (!group || !group.isMember(socket.userId)) return;

        // Update member's last known location in the database
        const member = group.getMember(socket.userId);
        if (member) {
          member.lastLocation = {
            lat,
            lng,
            speed: speed || 0,
            heading: heading || 0,
            updatedAt: new Date(),
          };

          // Update status based on speed
          if (group.status === 'active') {
            if (member.status !== 'sos') {
              member.status = speed < 2 ? 'stopped' : 'on-route';
            }
          }

          await group.save();
        }

        // Broadcast this member's location to all group members
        const roomName = `group:${groupId}`;
        io.to(roomName).emit('location:update', {
          userId: socket.userId,
          name: socket.user.name,
          lat,
          lng,
          speed: speed || 0,
          heading: heading || 0,
          status: member?.status || 'on-route',
          timestamp: Date.now(),
        });
      } catch (error) {
        console.error('[LocationHub] Update error:', error.message);
      }
    });

    /**
     * Unsubscribe from group location updates
     */
    socket.on('location:unsubscribe', (data) => {
      const { groupId } = data || {};
      if (groupId) {
        socket.leave(`group:${groupId}`);
        socket.groupId = null;
        console.log(`[LocationHub] ${socket.user.name} left group:${groupId}`);
      }
    });

    /**
     * Handle disconnection
     */
    socket.on('disconnect', () => {
      console.log(`[LocationHub] User disconnected: ${socket.user.name}`);
    });
  });
}

module.exports = { setupLocationHub };
