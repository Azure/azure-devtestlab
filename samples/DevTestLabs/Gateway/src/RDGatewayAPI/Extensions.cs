/**
 *  Copyright (c) Microsoft Corporation.
 *  Licensed under the MIT License.
 */

using Microsoft.WindowsAzure.Storage.Table;
using Newtonsoft.Json;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Threading.Tasks;

namespace RDGatewayAPI
{
    public static class Extensions
    {
        public static string ToJson(this ITableEntity tableEntity)
        {
            return JsonConvert.SerializeObject(tableEntity);
        }
    }
}
