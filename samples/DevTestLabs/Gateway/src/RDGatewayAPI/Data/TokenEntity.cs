/**
 *  Copyright (c) Microsoft Corporation.
 *  Licensed under the MIT License.
 */

using System;
using Microsoft.Azure.Cosmos.Table;

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
