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
    public static class ReportTokens
    {
        [FunctionName(nameof(ReportTokens))]
        public static async Task<IActionResult> Run(
            [HttpTrigger(AuthorizationLevel.Function, "get", Route = "report/tokens")] HttpRequest req,
            [Table("tokens")] CloudTable tokenTable,
            ILogger log)
        {
            TableContinuationToken continuationToken;

            try
            {
                continuationToken = PagedEntities<TokenEntity>.GetContinuationToken(req);
            }
            catch (Exception exc)
            {
                log.LogError($"Failed to deserialize continuation token", exc);

                return new BadRequestResult();
            }

            var segment = await tokenTable.ExecuteQuerySegmentedAsync(new TableQuery<TokenEntity>(), continuationToken).ConfigureAwait(false);

            var result = new PagedEntities<TokenEntity>(segment)
            {
                NextLink = segment.ContinuationToken != null ? PagedEntities<TokenEntity>.GetNextLink(req, segment.ContinuationToken) : null
            };

            return new OkObjectResult(result);
        }
    }
}
