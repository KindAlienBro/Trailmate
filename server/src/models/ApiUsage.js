const mongoose = require('mongoose');

const apiUsageSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },
  endpoint: {
    type: String,
    required: true,
  },
  method: {
    type: String,
    required: true,
  },
  status: {
    type: Number,
    required: true,
  },
  latency: {
    type: Number,
    required: true,
  },
  error: {
    type: String,
    default: null,
  }
}, {
  timestamps: true,
});

// Index for fast lookups and aggregations
apiUsageSchema.index({ userId: 1, createdAt: -1 });
apiUsageSchema.index({ endpoint: 1, createdAt: -1 });

module.exports = mongoose.model('ApiUsage', apiUsageSchema);
