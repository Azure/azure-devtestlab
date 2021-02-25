/**
 *  Copyright (c) Microsoft Corporation.
 *  Licensed under the MIT License.
 */

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Text;
using System.Threading.Tasks;
using System.Web;
using System.Xml;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.Azure.WebJobs.Host;
using Microsoft.WindowsAzure.Storage.Table;
using RDGatewayAPI.Data;

namespace RDGatewayAPI.Functions
{
    public static class ReportUsers
    {

        [FunctionName("ReportUsers")]
        public static async Task<HttpResponseMessage> Run([HttpTrigger(AuthorizationLevel.Function, "get", Route = "report/users")]HttpRequestMessage req,
                                                          [Table("users")] CloudTable userTable, TraceWriter log)
        {
            var continuationToken = default(TableContinuationToken);

            try
            {
                continuationToken = PagedEntities<UserEntity>.GetContinuationToken(req);
            }
            catch (Exception exc)
            {
                log.Error($"Failed to deserialize continuation token", exc);

                return req.CreateResponse(HttpStatusCode.BadRequest);
            }

            var segment = await userTable.ExecuteQuerySegmentedAsync<UserEntity>(new TableQuery<UserEntity>(), continuationToken).ConfigureAwait(false);

            var result = new PagedEntities<UserEntity>(segment)
            {
                NextLink = (segment.ContinuationToken != null ? PagedEntities<UserEntity>.GetNextLink(req, segment.ContinuationToken) : null)
            };

            return req.CreateResponse(HttpStatusCode.OK, result, "application/json");
        }
    }
}
