'use strict';

// SPDX-License-Identifier: MIT
// Order manager data access layer.
// Uses MongoDB (DDS) for storage.

const logManager = require('./lib/log-manager.js');
const metricsManager = require('./lib/metrics-manager.js');
const partitionManager = require('./lib/partition-manager.js');
const tokenManager = require('./lib/token-manager.js');
const helper = require('./lib/helper.js');

// Create an HTTP response object
function createResponse(statusCode, body) {
    return {
        statusCode: statusCode,
        body: body || '',
        headers: {
            'Content-Type': 'application/json',
        },
    };
}

// Get an order from MongoDB
async function getOrder(event) {
    await logManager.log(event, 'OrderManager', {
        message: 'DAL GetOrder() called.',
        orderId: event.pathParameters.resourceId,
    });

    const start = Date.now();
    const tenantId = tokenManager.getTenantId(event);

    try {
        const partition = await partitionManager.getPartition(
            event,
            partitionManager.ORDER_MANAGER,
            event.pathParameters.resourceId
        );

        if (!partition) {
            return createResponse(500, JSON.stringify({ error: 'Partition not found' }));
        }

        const client = await helper.getMongoClient();
        const db = client.db('saas');
        const collection = db.collection(partition.collectionName);

        let query;
        if (partition.isPooled) {
            query = { tenantId: tenantId, orderId: event.pathParameters.resourceId };
        } else {
            query = { orderId: event.pathParameters.resourceId };
        }

        const doc = await collection.findOne(query, { projection: { doc: 1, _id: 0 } });
        const response = createResponse(200, doc ? doc.doc : null);

        const end = Date.now();
        await metricsManager.recordMetricEvent(event, 'OrderManager', 'GetOrder', event, end - start);
        return response;
    } catch (err) {
        console.log('GetOrder error: ' + err);
        const end = Date.now();
        await metricsManager.recordMetricEvent(event, 'OrderManager', 'GetOrder', event, end - start);
        return createResponse(500, JSON.stringify({ error: err.message }));
    }
}

// Add or update an order in MongoDB
async function updateOrder(event) {
    await logManager.log(event, 'OrderManager', {
        message: 'DAL UpdateOrder() called.',
        orderId: event.pathParameters.resourceId,
    });

    const start = Date.now();
    const tenantId = tokenManager.getTenantId(event);

    try {
        const partition = await partitionManager.getPartition(
            event,
            partitionManager.ORDER_MANAGER,
            event.pathParameters.resourceId
        );

        if (!partition) {
            return createResponse(500, JSON.stringify({ error: 'Partition not found' }));
        }

        const client = await helper.getMongoClient();
        const db = client.db('saas');
        const collection = db.collection(partition.collectionName);

        let filter, updateDoc;
        if (partition.isPooled) {
            filter = { tenantId: tenantId, orderId: event.pathParameters.resourceId };
            updateDoc = {
                $set: {
                    tenantId: tenantId,
                    orderId: event.pathParameters.resourceId,
                    doc: event.body,
                },
            };
        } else {
            filter = { orderId: event.pathParameters.resourceId };
            updateDoc = {
                $set: {
                    orderId: event.pathParameters.resourceId,
                    doc: event.body,
                },
            };
        }

        await collection.updateOne(filter, updateDoc, { upsert: true });
        const response = createResponse(200, null);

        const end = Date.now();
        await metricsManager.recordMetricEvent(event, 'OrderManager', 'UpdateOrder', event, end - start);
        return response;
    } catch (err) {
        console.log('UpdateOrder error: ' + err);
        const end = Date.now();
        await metricsManager.recordMetricEvent(event, 'OrderManager', 'UpdateOrder', event, end - start);
        return createResponse(500, JSON.stringify({ error: err.message }));
    }
}

// Delete an order from MongoDB
async function deleteOrder(event) {
    await logManager.log(event, 'OrderManager', {
        message: 'DAL deleteOrder() called.',
        orderId: event.pathParameters.resourceId,
    });

    const start = Date.now();
    const tenantId = tokenManager.getTenantId(event);

    try {
        const partition = await partitionManager.getPartition(
            event,
            partitionManager.ORDER_MANAGER,
            event.pathParameters.resourceId
        );

        if (!partition) {
            return createResponse(500, JSON.stringify({ error: 'Partition not found' }));
        }

        const client = await helper.getMongoClient();
        const db = client.db('saas');
        const collection = db.collection(partition.collectionName);

        let filter;
        if (partition.isPooled) {
            filter = { tenantId: tenantId, orderId: event.pathParameters.resourceId };
        } else {
            filter = { orderId: event.pathParameters.resourceId };
        }

        await collection.deleteOne(filter);
        const response = createResponse(200, null);

        const end = Date.now();
        await metricsManager.recordMetricEvent(event, 'OrderManager', 'DeleteOrder', event, end - start);
        return response;
    } catch (err) {
        console.log('DeleteOrder error: ' + err);
        const end = Date.now();
        await metricsManager.recordMetricEvent(event, 'OrderManager', 'DeleteOrder', event, end - start);
        return createResponse(500, JSON.stringify({ error: err.message }));
    }
}

module.exports = {
    getOrder,
    updateOrder,
    deleteOrder,
};
