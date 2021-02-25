/**
 *  Copyright (c) Microsoft Corporation.
 *  Licensed under the MIT License.
 */

using System;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Threading.Tasks;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.Azure.WebJobs.Host;
using Microsoft.WindowsAzure.Storage.Table;
using RDGatewayAPI.Data;

namespace RDGatewayAPI.Functions
{
    public static class ReportTokens
    {
        [FunctionName("ReportTokens")]
        public static async Task<HttpResponseMessage> Run([HttpTrigger(AuthorizationLevel.Function, "get", Route = "report/tokens")]HttpRequestMessage req, 
                                                          [Table("tokens")] CloudTable tokenTable, TraceWriter log)
        {
            var continuationToken = default(TableContinuationToken);

            try
            {
                continuationToken = PagedEntities<TokenEntity>.GetContinuationToken(req);
            }
            catch (Exception exc)
            {
                log.Error($"Failed to deserialize continuation token", exc);

                return req.CreateResponse(HttpStatusCode.BadRequest);
            }

            var segment = await tokenTable.ExecuteQuerySegmentedAsync<TokenEntity>(new TableQuery<TokenEntity>(), continuationToken).ConfigureAwait(false);

            var result = new PagedEntities<TokenEntity>(segment)
            {
                NextLink = (segment.ContinuationToken != null ? PagedEntities<TokenEntity>.GetNextLink(req, segment.ContinuationToken) : null)
            };

            return req.CreateResponse(HttpStatusCode.OK, result, "application/json");
        }
    }
}
