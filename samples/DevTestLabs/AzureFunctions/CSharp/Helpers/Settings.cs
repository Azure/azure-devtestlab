using Microsoft.Build.Utilities;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using System;
using System.Collections.Generic;
using System.Text;

namespace AzureFunctions
{
    public class Settings
    {
        // this is the .net core way to build configuration, includes both local debugging (local.settings.jon) 
        // and running in Azure (Envrionment Variables set by app configuration)
        // More information found here:  https://docs.microsoft.com/en-us/aspnet/core/fundamentals/configuration/?view=aspnetcore-2.2
        private static IConfigurationRoot config = new ConfigurationBuilder()
            .SetBasePath(Environment.CurrentDirectory)
            .AddJsonFile("local.settings.json", optional: true, reloadOnChange: true)
            .AddEnvironmentVariables()
            .Build();

        private ILogger log { get; set; }

        public Settings(ILogger functionsLog)
        {
            log = functionsLog;
        }

        public T GetSetting<T>(string SettingName)
        {
            // Get the application setting and validate it.  This is stored as an environment 
            // variable in the App Service in Azure and in "local.settings.json" when local debugging
            var settingValue = config.GetValue<T>(SettingName);

            if (!CheckNullOrEmpty<T>(settingValue))
            {
                return settingValue;
            }
            else
            {
                log.LogError($"Missing [{SettingName}] in function application settings");
                return default(T);
            }
        }

        public static bool CheckNullOrEmpty<T>(T value)
        {
            if (typeof(T) == typeof(string))
                return string.IsNullOrEmpty(value as string);

            return value == null || value.Equals(default(T));
        }
    }
}
