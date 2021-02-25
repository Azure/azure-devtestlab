
using Microsoft.WindowsAzure.Storage;
using Microsoft.WindowsAzure.Storage.Table;
using Newtonsoft.Json;
﻿/**
 *  Copyright (c) Microsoft Corporation.
 *  Licensed under the MIT License.
 */

using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace RDGatewayAPI.Data
{
    public sealed class TokenEntity : TableEntity
    {
        public TokenEntity() : this(Guid.Empty)
        {
            // default constructor used for deserialization
        }

        public TokenEntity(Guid rowKey)
        {
            RowKey = rowKey.ToString();
            PartitionKey = DateTime.UtcNow.ToString("yyyy-MM");
            ETag = "*";
        }

        public Guid SessionId => Guid.Parse(RowKey);

        public Guid UserId { get; set; }

        public string Host { get; set; }

        public int Port { get; set; }

        public int ExpiresOn { get; set; }

    }
}
