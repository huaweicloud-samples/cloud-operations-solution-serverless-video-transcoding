'use strict';

// SPDX-License-Identifier: MIT
// Log manager: writes structured log entries to OBS

const helper = require('./helper.js');
const tokenManager = require('./token-manager.js');

// Log a message with tenant context to OBS
async function log(event, eventSource, message) {
    console.log(JSON.stringify(message));

    // Extract and add tenant id to the log message
    const tenantId = tokenManager.getTenantId(event);
    message.tenantId = tenantId;

    const currentTime = Date.now();
    const key = eventSource + '/' + currentTime;
    message.timestamp = new Date().toISOString().substr(0, 19).replace('T', ' ');

    await helper.uploadToObs(process.env.LogsBucketName, key, JSON.stringify(message));
}

module.exports = {
    log,
};
