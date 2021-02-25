/**
 *  Copyright (c) Microsoft Corporation.
 *  Licensed under the MIT License.
 */

using System;
using Microsoft.Azure.Cosmos.Table;

namespace RDGatewayAPI.Data
{
    public sealed class UserEntity : TableEntity
    {
        public UserEntity() : this(Guid.Empty)
        {
            // default constructor used for deserialization
        }

        public UserEntity(Guid rowKey)
        {
            RowKey = rowKey.ToString();
            PartitionKey = DateTime.UtcNow.ToString("yyyy");
            ETag = "*";
        }

        public Guid UserId => Guid.Parse(RowKey);

        public string UserPrincipalName { get; set; }

        public string UserDisplayName { get; set; }
    }
}
