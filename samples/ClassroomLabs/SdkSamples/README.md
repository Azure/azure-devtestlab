# How to set up a simple app to use the .NET SDK for Classroom Labs
* Login to [portal.azure.com](https://portal.azure.com).
* Go to the "Azure Active Directory" blade and click "Properties". Copy the Directory ID to your notes. It will be used as the `TenantId` in the `app.config`.
* Go back to the "Azure Active Directory" blade and Click "App Registrations".
* Click "New Application Registration".
  * `Name` doesn't matter, but make sure you select `NATIVE` as the `Application type`.
  * Set the `Sign-on URL` to https://dtlclient. This doesn't matter at this time.
* Go to the registered app page for your new app.
  * Copy the "ApplicationID" to your notes. It will be used as the `ClientId` in the `app.config`.
  * Go to "Settings/Owners" and add both your account as an owner.
  * Go to "Settings/Redirect URIs" and make sure "https://dtlclient" is on there.
  * Go to "Settings/Required Permissions" and click "Add". Type in "Windows Azure Service Management API" and check all permissions boxes.
  * On "Settings/Required Permissions" click "Grant Permissions". This should succeed.
* Next up, we can actually go create a lab account to make SDK calls against. Go to the Lab Services blade and create a new LabAccount.
* Once that LabAccount has been created, go to "Access Control (IAM)" and add your account as an owner of the lab account.
* Now you can set the rest of the options in the `app.config` and start making SDK calls!
