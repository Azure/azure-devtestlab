using Microsoft.WindowsAzure.Storage.Table;
﻿/**
 *  Copyright (c) Microsoft Corporation.
 *  Licensed under the MIT License.
 */

using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Newtonsoft.Json;
using System.IO;
using System.Xml;
using System.Net.Http;
using System.Web;

namespace RDGatewayAPI.Data
{
    public sealed class PagedEntities<T>
        where T : ITableEntity
    {
        private const string HEADER_X_FORWARDED_HOST = "X-Forwarded-Host";
        private const string HEADER_X_FORWARDED_PROTO = "X-Forwarded-Proto";
        private const string CONTINUATIONTOKEN_QUERYSTRING_KEY = "$skiptoken";

        private static string SerializeContinuationToken(TableContinuationToken continuationToken)
        {
            using (var buffer = new MemoryStream())
            using (var writer = new XmlTextWriter(buffer, Encoding.UTF8))
            {
                continuationToken.WriteXml(writer);

                writer.Flush();

                return Convert.ToBase64String(buffer.ToArray());
            }
        }

        private static TableContinuationToken DeserializeContinuationToken(string token)
        {
            var continuationToken = new TableContinuationToken();

            using (var buffer = new MemoryStream(Convert.FromBase64String(token)))
            using (var reader = new XmlTextReader(buffer))
            {
                continuationToken.ReadXml(reader);
            }

            return continuationToken;
        }

        public static string GetNextLink(HttpRequestMessage requestMessage, TableContinuationToken continuationToken)
        {
            var qs = HttpUtility.ParseQueryString(requestMessage.RequestUri.Query);
            qs.Set(CONTINUATIONTOKEN_QUERYSTRING_KEY, SerializeContinuationToken(continuationToken));

            var uri = new UriBuilder(requestMessage.RequestUri.GetLeftPart(UriPartial.Path));
            uri.Scheme = (requestMessage.Headers.TryGetValues(HEADER_X_FORWARDED_PROTO, out IEnumerable<string> protoValues) ? protoValues.FirstOrDefault() : uri.Scheme);
            uri.Host = (requestMessage.Headers.TryGetValues(HEADER_X_FORWARDED_HOST, out IEnumerable<string> hostValues) ? hostValues.FirstOrDefault() : uri.Host);
            uri.Port = -1; // remove the port information from URI
            uri.Query = qs.ToString();

            return uri.ToString();
        }

        public static TableContinuationToken GetContinuationToken(HttpRequestMessage requestMessage)
        {
            var continuationToken = default(TableContinuationToken);

            if (requestMessage.GetQueryNameValuePairs().ToDictionary(kv => kv.Key, kv => Uri.UnescapeDataString(kv.Value)).TryGetValue(CONTINUATIONTOKEN_QUERYSTRING_KEY, out string token))
            {
                continuationToken = DeserializeContinuationToken(Uri.UnescapeDataString(token));
            }

            return continuationToken;
        }

        public PagedEntities(IEnumerable<T> entities)
        {
            Entities = entities ?? throw new ArgumentNullException(nameof(entities));
        }

        [JsonProperty("value")]
        public IEnumerable<T> Entities { get; }

        [JsonProperty("nextLink", NullValueHandling = NullValueHandling.Ignore)]
        public string NextLink { get; set; }
    }
}
