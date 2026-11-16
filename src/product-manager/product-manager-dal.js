'use strict';

// SPDX-License-Identifier: MIT
// Product manager data access layer.
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

// Get a product from MongoDB
async function getProduct(event) {
    await logManager.log(event, 'ProductManager', {
        message: 'DAL GetProduct() called.',
        productId: event.pathParameters.resourceId,
    });

    const start = Date.now();
    const tenantId = tokenManager.getTenantId(event);

    try {
        const partition = await partitionManager.getPartition(
            event,
            partitionManager.PRODUCT_MANAGER,
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
            query = { tenantId: tenantId, productId: event.pathParameters.resourceId };
        } else {
            query = { productId: event.pathParameters.resourceId };
        }

        const doc = await collection.findOne(query, { projection: { doc: 1, _id: 0 } });
        const response = createResponse(200, doc ? doc.doc : null);

        const end = Date.now();
        await metricsManager.recordMetricEvent(event, 'ProductManager', 'GetProduct', event, end - start);
        return response;
    } catch (err) {
        console.log('GetProduct error: ' + err);
        const end = Date.now();
        await metricsManager.recordMetricEvent(event, 'ProductManager', 'GetProduct', event, end - start);
        return createResponse(500, JSON.stringify({ error: err.message }));
    }
}

// Add or update a product in MongoDB
async function updateProduct(event) {
    await logManager.log(event, 'ProductManager', {
        message: 'DAL UpdateProduct() called.',
        productId: event.pathParameters.resourceId,
    });

    const start = Date.now();
    const tenantId = tokenManager.getTenantId(event);

    try {
        const partition = await partitionManager.getPartition(
            event,
            partitionManager.PRODUCT_MANAGER,
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
            filter = { tenantId: tenantId, productId: event.pathParameters.resourceId };
            updateDoc = {
                $set: {
                    tenantId: tenantId,
                    productId: event.pathParameters.resourceId,
                    doc: event.body,
                },
            };
        } else {
            filter = { productId: event.pathParameters.resourceId };
            updateDoc = {
                $set: {
                    productId: event.pathParameters.resourceId,
                    doc: event.body,
                },
            };
        }

        await collection.updateOne(filter, updateDoc, { upsert: true });
        const response = createResponse(200, null);

        const end = Date.now();
        await metricsManager.recordMetricEvent(event, 'ProductManager', 'UpdateProduct', event, end - start);
        return response;
    } catch (err) {
        console.log('UpdateProduct error: ' + err);
        const end = Date.now();
        await metricsManager.recordMetricEvent(event, 'ProductManager', 'UpdateProduct', event, end - start);
        return createResponse(500, JSON.stringify({ error: err.message }));
    }
}

// Delete a product from MongoDB
async function deleteProduct(event) {
    await logManager.log(event, 'ProductManager', {
        message: 'DAL deleteProduct() called.',
        productId: event.pathParameters.resourceId,
    });

    const start = Date.now();
    const tenantId = tokenManager.getTenantId(event);

    try {
        const partition = await partitionManager.getPartition(
            event,
            partitionManager.PRODUCT_MANAGER,
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
            filter = { tenantId: tenantId, productId: event.pathParameters.resourceId };
        } else {
            filter = { productId: event.pathParameters.resourceId };
        }

        await collection.deleteOne(filter);
        const response = createResponse(200, null);

        const end = Date.now();
        await metricsManager.recordMetricEvent(event, 'ProductManager', 'DeleteProduct', event, end - start);
        return response;
    } catch (err) {
        console.log('DeleteProduct error: ' + err);
        const end = Date.now();
        await metricsManager.recordMetricEvent(event, 'ProductManager', 'DeleteProduct', event, end - start);
        return createResponse(500, JSON.stringify({ error: err.message }));
    }
}

module.exports = {
    getProduct,
    updateProduct,
    deleteProduct,
};
