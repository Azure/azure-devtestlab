# Create a Token Authentication Based Remote Desktop Gateway

## Requirements

The following to parameters are required to setup a RDGateway enabled lab:
* adminUsername – Administrator username for the gateway machines.
* adminPassword – Password for the Administrator account for the gateway machines.	
* sslCertificate – The Base64 encoding for SSL certificate for the gateway machine.
* sslCertificatePassword – The password for SSL certificate for the gateway machine.
* sslCertificateThumbprint - Certificate thumbprint for identification in the local certificate store of the SSL certificate.
* signCertificate – The Base64 encoding for signing certificate.  See [sample script](../../tools/Create-SigningCertificate.ps1) to create.
* signCertificatePassword – The password for signing certificate for the gateway machine.
* signCertificateThumbprint - Certificate thumbprint for identification in the local certificate store of the signing certificate.

The following to parameters are optional to setup a RDGateway enabled lab
* instanceCount – Number of gateway machines to create.
* alwaysOn – Whether or not to keep the created Azure Function App in a warm state.  Doing so will avoid delays when users first try to connect to their lab virtual machine in the morning.  
* tokenLifetime – The length of time the created token will be valid.  Format is HH:MM:SS.

The template requires access to a few other arm templates, PowerShell Scripts and  Remote Desktop Gateway Pluggable Authentication module (expected to be named RDGatewayFedAuth.msi that supports token authentication."

## Important Note
By using template, you agree to Remote Desktop Gateway’s terms. Click here to read [RD Gateway license terms](https://www.microsoft.com/en-us/licensing/product-licensing/products).  

For further information regarding Remote Gateway see [https://aka.ms/rds](https://aka.ms/rds) and [Deploy your Remote Desktop environment](https://docs.microsoft.com/en-us/windows-server/remote/remote-desktop-services/rds-deploy-infrastructure).
