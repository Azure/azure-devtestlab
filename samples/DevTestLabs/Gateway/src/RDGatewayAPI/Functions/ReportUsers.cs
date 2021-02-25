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
