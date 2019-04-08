This is an [Azure Dev Test Labs artifact](https://docs.microsoft.com/en-us/azure/lab-services/devtest-lab-artifact-author) for setting the time zone on Windows VMs.

Choose a time zone from the drop down list by its ID.  (Unfortunately, the `allowedValues` in a DevTestLabs artifact doesn't allow for a different display name.)

If you're not sure what time zone ID to choose, examine the output of `tzutil.exe /l` for a list.

Please note though, you should generally not change the time zone for *servers*. Leave that set to UTC and handle time zone conversions in your application code. Reserve using this artifact for setting the time zone on VMs intended for testing desktop client-side applications.
