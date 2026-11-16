'use strict';

// SPDX-License-Identifier: MIT
// Partition manager: determines the database partition (collection) for
// each tenant and service. Supports Pool and Silo partitioning models.

const tokenManager = require('./token-manager.js');
const logManager = require('./log-manager.js');
const helper = require('./helper.js');

const PRODUCT_MANAGER = 'ProductManager';
const ORDER_MANAGER = 'OrderManager';

const MODEL_SILO = 'Silo';
const MODEL_POOL = 'Pool';

// Hard-coded partition mapping. In production this would come from
// a configuration service or database.
const partitionMap = new Map([
    ['ProductManager', {
        serviceType: 'ProductService',
        model: 'Pool',
        collectionPrefix: 'products',
    }],
    ['OrderManager', {
        serviceType: 'OrderService',
        model: 'Silo',
        collectionPrefix: 'orders',
    }],
]);

// Determine the collection name for a given tenant and service.
// Returns an object: { collectionName, model, isPooled }
async function getPartition(event, serviceId, resourceId) {
    await logManager.log(event, serviceId, {
        message: 'Partition Manager: getPartition().',
        resourceId: resourceId,
    });

    const tenantId = tokenManager.getTenantId(event);
    const descriptor = lookupPartition(tenantId, serviceId);

    if (!descriptor) {
        return null;
    }

    await logManager.log(event, serviceId, {
        message: 'Partition Manager: collection is ' + descriptor.collectionPrefix,
        resourceId: resourceId,
    });

    let collectionName;
    if (serviceId === PRODUCT_MANAGER) {
        collectionName = buildCollectionName(tenantId, descriptor, 'products');
    } else if (serviceId === ORDER_MANAGER) {
        collectionName = buildCollectionName(tenantId, descriptor, 'orders');
    } else {
        return null;
    }

    return {
        collectionName: collectionName,
        model: descriptor.model,
        isPooled: descriptor.model === MODEL_POOL,
    };
}

// Lookup the partition descriptor from the configuration map
function lookupPartition(tenantId, serviceId) {
    console.log('looking up partition, tenantId = ' + tenantId + ' serviceId = ' + serviceId);
    if (partitionMap.has(serviceId)) {
        return partitionMap.get(serviceId);
    }
    return null;
}

// Build the collection name based on the partitioning model.
// Pool: single shared collection (e.g., "products_pooled")
// Silo: per-tenant collection (e.g., "orders_silo_tenant1")
function buildCollectionName(tenantId, descriptor, baseName) {
    if (descriptor.model === MODEL_POOL) {
        return baseName + '_pooled';
    } else if (descriptor.model === MODEL_SILO) {
        return baseName + '_silo_' + tenantId;
    }
    return baseName;
}

module.exports = {
    PRODUCT_MANAGER,
    ORDER_MANAGER,
    getPartition,
};
