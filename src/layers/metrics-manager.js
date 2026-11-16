'use strict';

// SPDX-License-Identifier: MIT
// Metrics manager: records application metrics to OBS

const helper = require('./helper.js');
const tokenManager = require('./token-manager.js');

// Record a metric event with tenant context to OBS
async function recordMetricEvent(event, eventSource, eventAction, context, currentDuration) {
    // Extract and add tenant id to the metric
    const tenantId = tokenManager.getTenantId(event);

    const metricEvent = {
        source: eventSource,
        type: 'ApplicationService',
        action: eventAction,
        duration: currentDuration,
        timestamp: new Date().toISOString().substr(0, 19).replace('T', ' '),
        tenantId: tenantId,
    };

    const currentTime = Math.floor(new Date() / 1000).toString();
    const key = eventSource + '/' + currentTime;

    await helper.uploadToObs(process.env.MetricsBucketName, key, JSON.stringify(metricEvent));
}

module.exports = {
    recordMetricEvent,
};
