Javascript to simplify the Claim Any process of a VM
The js directory contains scripts to connect and claim any VM. The app.html is an example of code to use the Javascript functions inside a page of your own website. Also, they require the registration of an app in the Azure AD.


App registration
1. To register a new application we need to first create the App registrations in Azure Active directory. To know more about this please    follow this link. We need to:
2. Sign in to the Azure portal
3. Choose your Azure AD tenant by selecting your account in the top right corner of the page
4. In the left-hand navigation pane, choose More Services, click App Registrations, and click Add
5. Follow the prompts and create a new application
6. Once the app is created, grant delegated permissions to Windows Azure Active Directory (Microsoft.Azure.ActiveDirectory) and Windows 
7. Azure Service Management API in the Required permissions Settings blade
8. Generate a valid key and copy it.
9. Register your App URL as the Reply URL's section
10.Edit manifest and set "oauth2AllowImplicitFlow": true


Placeholder replacement
Mandatory fields:
- ClientID, application ID provided when you register your app on Azure AD
- SubscriptionID, ID of the subscription where you ha deployed the resourrces
- ResourcegroupName, resource group name of the lab
- LabName, name of the lab
Optional Fields:
- Success Callback, called if claim action succeeds
- Failure Callback, called if claim action doesn't succeed
