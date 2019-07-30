# DevTest Labs Internal Support Page integration with Azure Functions
One way to leverage the Internal Support page is by providing information for the team about the lab and the resources available.  A challenge in this approach is that the page can get out of date.  To resolve this, we can provide an 'update' button to refresh the page.

## Overview

The sample provided is available as both C# and PowerShell, both using Azure Functions v2.  There are two functions:
- **UpdateInternalSupportPage**:  This function is used for refreshing the content in the lab's internal support page.  There is a button on the page that invokes the function (http trigger) to refresh the page and returns an html page with success once complete.
- **ApplyWindowsUpdateArtifact**:  This function applies windows update artifacts to a virtual machine in the lab.  It's an example of other actions that can be initiated from the internal support page.  In this case, windows-based virtual machines that have not had windows updates run recently will have a link on the internal support page to run the artifact (which calls this http trigger azure function).

## Issues

Log issues on the [DevTest Labs Issues page](https://github.com/Azure/azure-devtestlab/issues). 

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details
