/* ------------------------------------------------------------------------------------------------	/* ------------------------------------------------------------------------------------------------
Copyright (c) 2019 Microsoft Corporation
 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and	Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
associated documentation files (the "Software"), to deal in the Software without restriction,	associated documentation files (the "Software"), to deal in the Software without restriction,
including without limitation the rights to use, copy, modify, merge, publish, distribute,	including without limitation the rights to use, copy, modify, merge, publish, distribute,
sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is	sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:	furnished to do so, subject to the following conditions:
 The above copyright notice and this permission notice shall be included in all copies or	The above copyright notice and this permission notice shall be included in all copies or
substantial portions of the Software.	substantial portions of the Software.
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND	NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,	NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,	DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
------------------------------------------------------------------------------------------------ */
#r "Microsoft.WindowsAzure.Storage"
#r "Microsoft.Azure.WebJobs.Extensions.Http"
#r "Newtonsoft.Json"

#load "..\Shared\Data\UserEntity.csx"

using System;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Threading.Tasks;
using System.Text;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.Azure.WebJobs.Host;
using Microsoft.WindowsAzure.Storage.Table;
using Newtonsoft.Json;

public static async Task<IActionResult> Run(HttpRequest req, CloudTable userTable, ILogger log)
{
    TableQuery<UserEntity> query = new TableQuery<UserEntity>();

    StringBuilder sb = new StringBuilder();
 
    TableContinuationToken token = null;
    do
    {
        TableQuerySegment<UserEntity> resultSegment = await userTable.ExecuteQuerySegmentedAsync(query, token);
        token = resultSegment.ContinuationToken;

        foreach (UserEntity entity in resultSegment.Results)
        {
            sb.AppendLine($"{JsonConvert.SerializeObject(entity)},");
        }
    } while (token != null);

    return new OkObjectResult(sb.ToString());  
}
