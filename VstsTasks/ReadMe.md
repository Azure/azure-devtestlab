# Azure DevTest Labs Tasks

Collection of build/release tasks to interact with [Azure DevTest Labs](https://azure.microsoft.com/en-us/services/devtest-lab/).

# References

**tfx** - [TFS Cross Platform Command Line Interface](https://github.com/Microsoft/tfs-cli)

# General Info

To package the extension, run the following command:

`tfx extension create --manifest-globs vss-extension.json`

To test each task independently, for example, in MYPROJ (i.e. a single task instead of the entire package):

1. Connect to MYPROJ via tfx command (same applies for any other project in visualstudio.com).

   `tfx login --service-url https://myproj.visualstudio.com/DefaultCollection --token <PAT>`

2. Run the following command for the task you want to test, respectively.

   `tfx build tasks upload --task-path .\AzureDtlCreateCustomImage --overwrite`

   `tfx build tasks upload --task-path .\AzureDtlCreateEnvironment --overwrite`

   `tfx build tasks upload --task-path .\AzureDtlDeleteEnvironment --overwrite`

   `tfx build tasks upload --task-path .\AzureDtlCreateVM --overwrite`

   `tfx build tasks upload --task-path .\AzureDtlDeleteVM --overwrite`

3. Go to a build / release definition.
4. Add a step, locating your task, and validate its functionality.
