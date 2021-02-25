/* ------------------------------------------------------------------------------------------------
Copyright (c) 2018 Microsoft Corporation

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
associated documentation files (the "Software"), to deal in the Software without restriction,
including without limitation the rights to use, copy, modify, merge, publish, distribute,
sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or
substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
------------------------------------------------------------------------------------------------ */

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
