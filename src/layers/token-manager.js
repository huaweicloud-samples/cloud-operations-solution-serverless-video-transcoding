'use strict';

// SPDX-License-Identifier: MIT
// Token manager: extracts tenant ID from JWT bearer token

const nJwt = require('njwt');

// Shared signing key (must match the client-side key).
// 生产环境通过环境变量 SAAS_JWT_SECRET 注入；下方值为本地演示占位，不得用于生产。
const signingKey = process.env.SAAS_JWT_SECRET || '<your-signing-key>';

// Get the tenant identifier from the supplied event context
function getTenantId(event) {
    const headers = event.headers || {};
    const bearerToken = headers['Authorization'] || headers['authorization'] || '';
    let tenantId = '';
    try {
        const jwtToken = bearerToken.substring(bearerToken.indexOf(' ') + 1);
        const verifiedJwt = nJwt.verify(jwtToken, signingKey);
        tenantId = verifiedJwt.body.tenantId;
    } catch (e) {
        console.log('Error verifying token: ' + e);
    }
    return tenantId;
}

module.exports = {
    getTenantId,
};
