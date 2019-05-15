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

using Microsoft.WindowsAzure.Storage.Table;
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
