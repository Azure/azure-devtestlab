This folder contains: 

A complete manual which describes the solution implemented and how to deploy the Azure DevTest Lab for both class and self-service scenario

An excel which helps in calculate an estimate of the price to run the solution

-------------------------------------------------------------------------------

Creating the appropriate Azure credential file to run the scripts from command line

In 'powershell' do the following:

Login-AzureRmAccount
Set-AzureRmContext -SubscriptionId "XXXXX-XXXX-XXXX"
Save-AzureRMProfile -Path "$env:APPDATA\AzProfile.txt"

This saves the credentials file in the location on disk where the script look for by default.
