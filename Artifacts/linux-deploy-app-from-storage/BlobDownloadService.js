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

/**
* Creates a new BlobDownloadService object with the specifed connection info.
* @class
* The BlobDownloadService class is used to download the contents of a container 
* from the Microsoft Azure Blob Service.
* 
* The following properties can be set on the blob download service:
* connectionString      (required) The connection string used to connect to the Azure Blob Service.
*
* @constructor
*
* @param {object} [connectionInfo]  The configuration used to interact with the Azure Blob Service.
*/
function BlobDownloadService(connectionString) {
    this._blobSvc = azure.createBlobService(connectionString);
    this._blobRefs = [];
    this._blobs = [];
    this._container = "";
    this._options = {
        delimiter: '\\'
    };
}

// Private methods

/**
* Blob resource aggregator.  Aggregates pages of blob metadata
* returned from the Azure storage client.
* @ignore
*
* @param {object}           err         An error, if one has been captured.
* @param {object}           result      A collection of blob metadat returned from
*                                       the Azure Blob Service.
* @param {errorOrResult}    callback    'err' will contain information if an error occurs;
*                                       'result' will contain a page of blob metadata.
*/
BlobDownloadService.prototype._aggregateBlobs = function (err, result, callback) {
    if (err) {
        callback(err);
    } else {
        this._blobRefs = this._blobRefs.concat(result.entries);

        if (result.continuationToken !== null) {
            this._blobSvc.listBlobsSegmented(
                this._container,
                result.continuationToken,
                this._options,
                this._aggregateBlobs);
        }
        else {
            callback(undefined, this._blobRefs);
        }
    }
};

// Public methods

/**
* Downloads the specified container from the Azure Blob Service to the specified
* file path.
*
* @this {BlobDownloadService}
* @param {string}           [container]     (required) The name of an Azure Blob Service container.
* @param {string}           [destination]   (required) A folder path on the client lab VM that will 
*                                           contain application files downloaded from the Azure Blob Service.
* @param {errorOrResult}    [callback]      'err' will contain information if an error occurs;
*                                           'result' will contain a page of blob metadata.
*/
BlobDownloadService.prototype.downloadContainer = function (container, destination, callback) {
    var self = this;

    self._blobSvc.listBlobsSegmented(container, null, this._options, function (err, result, response) {
        self._aggregateBlobs(err, result, function (err, blobs) {
            if (err) {
                callback(err, null);
            }

            var blobCount = blobs.length;
            var blobsDownloaded = 0;

            for (var i = 0; i < blobCount; i += 1) {
                var blobName = blobs[i].name;
                var filePath = destination + '/' + blobName;

                mkdirp.sync(path.dirname(filePath));
                console.log(blobName + ' -> ' + filePath);

                self._blobSvc.getBlobToLocalFile(
                    container,
                    blobName,
                    filePath,
                    function (err, serverBlob) {
                        blobsDownloaded += 1;
                        self._blobs.push(serverBlob);

                        if (err) {
                            callback(err, null);
                        }
                        else if ((result.continuationToken === null) && (blobsDownloaded >= blobCount)) {
                            // No further pages to download, all blobs in the current page have been accounted for
                            // Time to wrap up and call the caller back.
                            callback(null, self._blobs);
                        }
                    });
            }
        });
    });
};

module.exports = BlobDownloadService;