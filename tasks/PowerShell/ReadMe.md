# Azure DevTest Labs Tasks

Collection of build/release tasks to interact with [Azure DevTest Labs](https://azure.microsoft.com/en-us/services/devtest-lab/).

## Contributions

Contributions are encouraged and welcome. However, the team reserves the right to decide which contributions will be included in future releases of the extension.

The process to get changes published requires the team to review, test and package the extension. Submit a pull request to get the process started.

### Submission Requirements

Create a pull request that includes
* a detailed description of the new contribution or the change,
* steps on how to test the task and/or changes,
* screenshots of the expected output, where possible, from your own testing, and
* updated documentation (i.e. updated top level `README.md`).

## How to Test

### References

**tfx** - [TFS Cross Platform Command Line Interface](https://github.com/Microsoft/tfs-cli)

### General Info

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
	
   `tfx build tasks upload --task-path .\AzureDtlPopulateEnvironment --overwrite`

3. Go to a build / release definition.
4. Add a step, locating your task, and validate its functionality.
