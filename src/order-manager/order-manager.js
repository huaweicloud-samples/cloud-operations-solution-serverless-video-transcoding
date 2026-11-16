'use strict';

// SPDX-License-Identifier: MIT
// Order manager handler for FunctionGraph.
// Receives APIG trigger events and delegates to the DAL layer.

const logManager = require('./lib/log-manager.js');
const dal = require('./order-manager-dal.js');

// Fetch an order by OrderId
exports.get = async (event, context) => {
    await logManager.log(event, 'OrderManager', {
        message: 'GetOrder() called.',
        orderId: event.pathParameters.resourceId,
    });

    const response = await dal.getOrder(event);
    return response;
};

// Add or update an order
exports.put = async (event, context) => {
    await logManager.log(event, 'OrderManager', {
        message: 'PutOrder() called.',
        orderId: event.pathParameters.resourceId,
    });

    const response = await dal.updateOrder(event);
    return response;
};

// Delete an order by OrderId
exports.delete = async (event, context) => {
    await logManager.log(event, 'OrderManager', {
        message: 'deleteOrder() called.',
        orderId: event.pathParameters.resourceId,
    });

    const response = await dal.deleteOrder(event);
    return response;
};
