/**
 *  Copyright (c) Microsoft Corporation.
 *  Licensed under the MIT License.
 */

using System;
using System.Globalization;
using System.Security.Cryptography;
using System.Security.Cryptography.X509Certificates;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;
using RDGatewayAPI.Data;

namespace RDGatewayAPI.Functions
{
    public static class CreateToken
    {
        private static readonly DateTime PosixBaseTime = new DateTime(1970, 1, 1, 0, 0, 0, 0);
        private static readonly Regex TokenParseExpression = new Regex("(?<key>Host|Port|ExpiresOn)=(?<value>.+?)(?=&)", RegexOptions.Compiled);


        [FunctionName(nameof(CreateToken))]
        public static IActionResult Run(
            [HttpTrigger(AuthorizationLevel.Function, "get", Route = "host/{host}/port/{port}")] HttpRequest req,
            [Queue("track-token")] ICollector<string> trackTokenQueue,
            ExecutionContext executionContext,
            string host, int port,
            ILogger log)
        {
            const string USER_OBJECTID_HEADER = "x-ms-client-object-id";

            var user = req.Headers.TryGetValue(USER_OBJECTID_HEADER, out var values) ? values.FirstOrDefault() : default;

            if (string.IsNullOrEmpty(user) || !Guid.TryParse(user, out var userId))
            {
                log.LogError($"BadRequest - missing or invalid request header '{USER_OBJECTID_HEADER}'");

                return new BadRequestResult();
            }

            try
            {
                var certificate = GetCertificate(); // get the signing certificate
                var response = new { token = GetToken(certificate, host, port) }; // get the signed authentication token

                TrackToken(trackTokenQueue, req.GetCorrelationId().GetValueOrDefault(executionContext.InvocationId), userId, response.token);

                return new OkObjectResult(response);
            }
            catch (Exception exc)
            {
                log.LogError(exc, $"Failed to process request {executionContext.InvocationId}");

                return new StatusCodeResult(500);
            }
        }


        private static X509Certificate2 GetCertificate()
        {
            try
            {
                // get the base64 encoded secret and decode
                var signCertificate = Environment.GetEnvironmentVariable("SignCertificate");
                var signCertificateBuffer = Convert.FromBase64String(signCertificate);

                // unwrap the json data envelope
                var envelope = JsonConvert.DeserializeAnonymousType(Encoding.UTF8.GetString(signCertificateBuffer), new { data = string.Empty, password = string.Empty });

                // return the certificate
                return new X509Certificate2(Convert.FromBase64String(envelope.data), envelope.password, X509KeyStorageFlags.MachineKeySet | X509KeyStorageFlags.PersistKeySet | X509KeyStorageFlags.Exportable);
            }
            catch (Exception exc)
            {
                throw new Exception($"Failed to load certificate from KeyVault", exc);
            }
        }

        private static string GetToken(X509Certificate2 certificate, string host, int port)
        {
            const string AUTH_TOKEN_PATTERN = "{0}&Signature=1|SHA256|{1}|{2}";
            const string MACHINE_TOKEN_PATTERN = "Host={0}&Port={1}&ExpiresOn={2}";

            // create the machine token and sign the data
            var machineToken = string.Format(CultureInfo.InvariantCulture, MACHINE_TOKEN_PATTERN, host, port, GetExpirationTimestamp());
            var machineTokenBuffer = Encoding.ASCII.GetBytes(machineToken);
            var machineTokenSignature = certificate.GetRSAPrivateKey().SignData(machineTokenBuffer, HashAlgorithmName.SHA256, RSASignaturePadding.Pkcs1);

            // wrap the machine token
            return string.Format(CultureInfo.InvariantCulture, AUTH_TOKEN_PATTERN, machineToken, certificate.Thumbprint, Uri.EscapeDataString(Convert.ToBase64String(machineTokenSignature)));
        }

        private static long GetExpirationTimestamp()
        {
            var tokenLifetime = Environment.GetEnvironmentVariable("TokenLifetime");
            var endOfLife = DateTime.UtcNow.AddMinutes(1);

            if (!string.IsNullOrEmpty(tokenLifetime))
            {
                try
                {
                    var duration = TimeSpan.Parse(tokenLifetime); // parse token lifetime
                    endOfLife = DateTime.UtcNow.Add(duration); // apply lifetime from configuration
                }
                catch (Exception exc)
                {
                    throw new Exception($"Failed to parse token lifetime '{tokenLifetime}' from configuration", exc);
                }
            }

            return (long)endOfLife.Subtract(PosixBaseTime).TotalSeconds; // return lifetime in posix format
        }


        private static void TrackToken(ICollector<string> collector, Guid correlationId, Guid userId, string token)
        {
            var tokenEntity = new TokenEntity(correlationId)
            {
                UserId = userId
            };

            foreach (Match match in TokenParseExpression.Matches(token))
            {
                var key = match.Groups["key"].Value;
                var value = match.Groups["value"].Value;

                switch (key)
                {
                    case "Host":
                        tokenEntity.Host = value;
                        break;

                    case "Port":
                        tokenEntity.Port = int.Parse(value);
                        break;

                    case "ExpiresOn":
                        tokenEntity.ExpiresOn = int.Parse(value);
                        break;
                }
            }

            collector.Add(tokenEntity.ToJson());
        }
    }
}
