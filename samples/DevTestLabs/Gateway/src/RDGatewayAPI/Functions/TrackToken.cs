/**
 *  Copyright (c) Microsoft Corporation.
 *  Licensed under the MIT License.
 */

using System;
using System.Threading.Tasks;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Host;
using Microsoft.WindowsAzure.Storage.Table;
using RDGatewayAPI.Data;

namespace RDGatewayAPI.Functions
{
    public static class TrackToken
    {
        private static async Task Track(CloudTable table, ITableEntity entity, TraceWriter log)
        {
            log.Info($"Track {entity.GetType().Name}: {entity.RowKey}");

            var operation = TableOperation.InsertOrReplace(entity);

            await table.ExecuteAsync(operation).ConfigureAwait(false);
        }

        [FunctionName("TrackToken")]
        public static async Task Run([QueueTrigger("track-token")]TokenEntity tokenEntity, [Table("tokens")] CloudTable tokenTable, [Table("users")] CloudTable userTable, TraceWriter log)
        {
            await Track(tokenTable, tokenEntity, log);

            var userEntity = new UserEntity(tokenEntity.UserId);

            await Track(userTable, userEntity, log);
        }
    }
}
