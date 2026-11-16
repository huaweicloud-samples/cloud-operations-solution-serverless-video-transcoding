'use strict';

// SPDX-License-Identifier: MIT
// Product manager handler for FunctionGraph.
// Receives APIG trigger events and delegates to the DAL layer.

const logManager = require('./lib/log-manager.js');
const dal = require('./product-manager-dal.js');

// Fetch a product by ProductId
exports.get = async (event, context) => {
    await logManager.log(event, 'ProductManager', {
        message: 'GetProduct() called.',
        productId: event.pathParameters.resourceId,
    });

    const response = await dal.getProduct(event);
    return response;
};

// Add or update a product
exports.put = async (event, context) => {
    await logManager.log(event, 'ProductManager', {
        message: 'PutProduct() called.',
        productId: event.pathParameters.resourceId,
    });

    const response = await dal.updateProduct(event);
    return response;
};

// Delete a product by ProductId
exports.delete = async (event, context) => {
    await logManager.log(event, 'ProductManager', {
        message: 'deleteProduct() called.',
        productId: event.pathParameters.resourceId,
    });

    const response = await dal.deleteProduct(event);
    return response;
};
