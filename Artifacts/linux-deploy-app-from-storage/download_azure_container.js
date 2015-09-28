//*********************************************************
//
//    Copyright (c) Microsoft. All rights reserved.
//    This code is licensed under the MIT License.
//    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF 
//    ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED 
//    TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A 
//    PARTICULAR PURPOSE AND NONINFRINGEMENT.
//
//*********************************************************

var path = require('path');
var mkdirp = require('mkdirp');
var azure = require('azure-storage');
var BlobDownloadService = require('./BlobDownloadService');

if (process.argv.length !== 5) {
    console.log('Usage: download_azure_container <container> <destination> <storage connection string>');
    process.exit(1);
}

var connectionInfo = {
    container: process.argv[2],
    destination: process.argv[3],
    connectionString: process.argv[4]
};

// catch the uncaught errors that weren't wrapped in a domain or try catch statement
// do not use this in modules, but only in applications, as otherwise we could have multiple of these bound
process.on('uncaughtException', function (err) {
    console.error(err);
    process.exit(1);
});

var downloadService = new BlobDownloadService(connectionInfo.connectionString);

downloadService.downloadContainer(connectionInfo.container, connectionInfo.destination, function (err) {
    if (err) {
        console.err("An error occurred while enumerating this blobs in the specified container.");
        throw err;
    }
});