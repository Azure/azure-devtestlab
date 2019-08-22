# Azure Pipelines DevTest Labs Tasks

Collection of build/release tasks to interact with [Azure DevTest Labs](https://azure.microsoft.com/en-us/services/devtest-lab/).

# References

* [Azure Pipelines Tasks](https://github.com/microsoft/azure-pipelines-tasks) - source code for out of the box tasks provided with [Azure DevOps](https://azure.microsoft.com/en-ca/services/devops/).
* Article [Add a build or release task](https://docs.microsoft.com/en-us/azure/devops/extend/develop/add-build-task?view=azure-devops&viewFallbackFrom=vsts).

# Release Notes

See the [RELEASENOTES.md](RELEASENOTES.md) file for details.

# Pre-requisites

The following are tools used to create these tasks and are recommended.

* The latest version of [Visual Studio Code](https://code.visualstudio.com/).
* The latest version of [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest).
* The latest version of [Node.js](https://nodejs.org/en/download/).
* [Typescript Compiler](https://www.npmjs.com/package/typescript) v2.2.0 or later.
  * This should already be part of the dependencies, when configuring the project for the first time.
* [TFS Cross Platform Command Line Interface](https://github.com/Microsoft/tfs-cli)
  * The `tfx-cli` can be installed using `npm`, a component of `Node.js` by running `npm i -g tfx-cli`

# First time development environment setup

To configure your local environment, after cloning the repo, do the following:

1. From within VS Code's `Terminal` window, navigate to `./tasks/Node`
2. Generate file `authfile.json` to be used for running the tasks locally.

   If you're asked to authenticate, run command:

   `az login --use-device-code`

   To generate the file, run command:

   `az ad sp create-for-rbac --sdk-auth > authfile.json`

2. Run command to download all dependencies.

   `npm run init-mods`

3. Run command to initialize your development environment. The command will clean the `out` folder, copy the necessary files and compile the task code for local running.

   `npm run init-dev`

After doing the above steps you can just compile the code by calling `tsc` in the command line.

# Locally test your changes

To test any changes locally, do the following:

1. For now, open the corresponding `task.ts` file, navigate to the function `testRun()`, pay attention to any references to `data`. The values are expected to come from a file called `testdata.json` that you can place in the same folder as `task.ts`.

   Here's a sample `testdata.json` for task `AzureDtlDeleteVm`. Replace any values in angle brackets (e.g. `<subId>`).

   ```JSON
   {
     "subscriptionId": "<subId>",
     "labVmId": "/subscriptions/<subId>/resourcegroups/<rgName>/providers/microsoft.devtestlab/labs/<labName>/virtualmachines/<vmName>"
   }
   ```

   >**TODO:** _Add tests that will supersede the above approach._
2. Compile the code.

   `tsc`

   or, copy structure and compile the code.

   `npm run build-dev`

3. Run the task you want to test; for example, to test creating a custom image, run command:

   `node .\out\tasks\AzureDtlCreateCustomImage\task.js --test`

You can also combine commands as follows:

`cls; npm run build-dev; node .\out\tasks\AzureDtlCreateCustomImage\task.js --test`

# Package the extension for publishing

To package the extension for publishing, run command:

`npm run package`

A file similar to `./dist/ms-azuredevtestlabs-dev.dtl-tasks-0.0.0.vsix` will be created.