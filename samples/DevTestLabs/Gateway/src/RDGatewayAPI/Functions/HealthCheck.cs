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
    public static class HealthCheck
    {

        [FunctionName("HealthCheck")]
        public static async Task<HttpResponseMessage> Run([HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "health")]HttpRequestMessage req, TraceWriter log)
        {           
            // This function is used to by the Azure LB to check the backend health.
            // Add additional checks, if you need more precise health reporting for 
            // the load balancer probes.

            return req.CreateResponse(HttpStatusCode.OK);
        }
    }
}
