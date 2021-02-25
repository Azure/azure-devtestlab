/**
 *  Copyright (c) Microsoft Corporation.
 *  Licensed under the MIT License.
 */

using System;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.Cosmos.Table;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.Extensions.Logging;
using RDGatewayAPI.Data;

namespace RDGatewayAPI.Functions
{
    public static class ReportUsers
    {
        [FunctionName(nameof(ReportUsers))]
        public static async Task<IActionResult> Run(
            [HttpTrigger(AuthorizationLevel.Function, "get", Route = "report/users")] HttpRequest req,
            [Table("users")] CloudTable userTable,
            ILogger log)
        {
            TableContinuationToken continuationToken;

            try
            {
                continuationToken = PagedEntities<UserEntity>.GetContinuationToken(req);
            }
            catch (Exception exc)
            {
                log.LogError($"Failed to deserialize continuation token", exc);

                return new BadRequestResult();
            }

            var segment = await userTable.ExecuteQuerySegmentedAsync(new TableQuery<UserEntity>(), continuationToken).ConfigureAwait(false);

            var result = new PagedEntities<UserEntity>(segment)
            {
                NextLink = segment.ContinuationToken != null ? PagedEntities<UserEntity>.GetNextLink(req, segment.ContinuationToken) : null
            };

            return new OkObjectResult(result);
        }
    }
}
