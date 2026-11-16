'use strict';

// SPDX-License-Identifier: MIT
// Multi-tenant SaaS helper utilities for Huawei Cloud FunctionGraph

const { MongoClient } = require('mongodb');
const ObsClient = require('esdk-obs-nodejs');

// Reusable MongoDB client (connection pooling across invocations)
let mongoClient = null;

// Reusable OBS client
let obsClient = null;

// Get or create a MongoDB connection
async function getMongoClient() {
    if (!mongoClient) {
        const connStr = process.env.DDS_CONNECTION_STRING;
        mongoClient = new MongoClient(connStr, {
            connectTimeoutMS: 5000,
            socketTimeoutMS: 10000,
        });
        await mongoClient.connect();
        console.log('MongoDB connection established');
    }
    return mongoClient;
}

// Get or create an OBS client
function getObsClient() {
    if (!obsClient) {
        obsClient = new ObsClient({
            access_key_id: process.env.OBS_ACCESS_KEY,
            secret_access_key: process.env.OBS_SECRET_KEY,
            server: process.env.OBS_ENDPOINT,
        });
    }
    return obsClient;
}

// Upload content to an OBS bucket
async function uploadToObs(bucketName, key, body) {
    const obs = getObsClient();
    try {
        const result = await obs.putObject({
            Bucket: bucketName,
            Key: key,
            Body: body,
        });
        if (result.CommonMsg.Status < 300) {
            console.log('Upload success: ' + bucketName + '/' + key);
        } else {
            console.log('Upload failed, status: ' + result.CommonMsg.Status);
        }
    } catch (err) {
        console.log('OBS upload error: ' + err);
    }
}

// Ensure a MongoDB collection exists (creates implicitly on first insert,
// but we call this for explicit logging)
async function ensureCollection(db, collectionName) {
    const dbObj = mongoClient.db(db);
    const collections = await dbObj.listCollections({ name: collectionName }).toArray();
    if (collections.length === 0) {
        console.log('Collection does not exist, will be created on insert: ' + collectionName);
    }
    return dbObj.collection(collectionName);
}

module.exports = {
    getMongoClient,
    getObsClient,
    uploadToObs,
    ensureCollection,
};
