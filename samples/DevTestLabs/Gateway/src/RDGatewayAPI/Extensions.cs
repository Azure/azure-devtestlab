/**
 *  Copyright (c) Microsoft Corporation.
 *  Licensed under the MIT License.
 */

using System;
using System.Linq;
using Microsoft.AspNetCore.Http;
using Microsoft.Azure.Cosmos.Table;
using Newtonsoft.Json;

namespace RDGatewayAPI
{
    public static class Extensions
    {
        public static string ToJson(this ITableEntity tableEntity)
        {
            if (tableEntity is null)
            {
                throw new ArgumentNullException(nameof(tableEntity));
            }

            return JsonConvert.SerializeObject(tableEntity);
        }

        public static Guid? GetCorrelationId(this HttpRequest httpRequest)
        {
            const string CORRELATION_ID_HEADER = "X-Correlation-Id";

            if (httpRequest is null)
            {
                throw new ArgumentNullException(nameof(httpRequest));
            }

            if (httpRequest.Headers.TryGetValue(CORRELATION_ID_HEADER, out var correlationIdHeaders) && Guid.TryParse(correlationIdHeaders.First(), out var correlationId))
            {
                return correlationId;
            }

            return null;
        }
    }
}
