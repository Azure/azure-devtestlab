#r "Microsoft.WindowsAzure.Storage"
#r "Newtonsoft.Json"

#load "..\Shared\Data\TokenEntity.csx"
#load "..\Shared\Data\UserEntity.csx"

using System;
using System.Threading.Tasks;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Host;
using Microsoft.WindowsAzure.Storage.Table;

private static async Task Track(CloudTable table, ITableEntity entity, ILogger log)
{
    log.LogInformation($"Track {entity.GetType().Name}: {entity.RowKey}");

    var operation = TableOperation.InsertOrReplace(entity);

    await table.ExecuteAsync(operation).ConfigureAwait(false);
}

public static async Task Run(TokenEntity tokenEntity, CloudTable tokenTable, CloudTable userTable, ILogger log)
{
    await Track(tokenTable, tokenEntity, log);

    var userEntity = new UserEntity(tokenEntity.UserId);

    await Track(userTable, userEntity, log);
}
