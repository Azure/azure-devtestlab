// Copyright (c) Microsoft Corporation. All rights reserved.

using System.Web.Script.Serialization;

namespace SeleniumGridSetupService
{
    internal class InputConfig
    {
        public string SeleniumGridJarFile;
        public string Role;
        public string HubRegisterUrl;
        public string ConfigFile;
        public string AdditionalParameters;

        public InputConfig()
        {

        }

        public InputConfig(string[] args)
        {
            SeleniumGridJarFile = args[0];
            Role = args[1];
            HubRegisterUrl = args[2];
            ConfigFile = args[3];
            AdditionalParameters = args[4];
        }

        public static InputConfig CreateInputConfig(string serializedInputConfig)
        {
            return new JavaScriptSerializer().Deserialize<InputConfig>(serializedInputConfig);
        }

        override public string ToString()
        {
            return new JavaScriptSerializer().Serialize(this);
        }
    }
}
