# Version 3.0.0

## Upgrade Steps
- None for the extension. It will be available automatically.
- Corresponding new versions of the tasks will need to be explicitly selected.

## Breaking Changes
The following considerations should be taken when updating from previous versions of the tasks.

### Create VM
* Move parameter value for `-newVMName` to field `Virtual Machine`.
* Reselect the template under `Template File`.
* Under `Output Variables`, specify a `Reference name` (i.e. `vm`).
* Take note of the new output variable for the lab VM ID (i.e. `vm.labVmId`).

### Delete VM
* A lab is now required for selection.
* Change the Lab VM to match, if using the Create VM task (i.e. `vm.labVmId`).

### Create Custom Image
* Change the reference to the `Virtual Machine`, if using one generated from the Create VM task (i.e. `vm.labVmId`).
* Under `Output Variables`, specify a `Reference name` (i.e. `ci`).
* Take note of the new output variable for the custom image ID (i.e. `ci.customImageId`).

### Delete Custom Image
* None. New task.

### Create Environment
* Option `Create output variables based on the environment template output?` will need to be reselected.

### Populate Environment
* **Deprecated**. It is superseded by task `Update Environment`.
* Replace with task `Update Environment`.

### Update Environment
* None. New task.

### Delete Environment
* No impact.

## New Features
- Moved implementation from `PowerShell` to `Node.js` to work with cross-platform agents (Linux, macOS, or Windows).
- Added new task named `Delete Custom Image`.

## Bug Fixes
- Removed references to non-supported handlers.

## Improvements
- Tasks now support cross-platform agents (Linux, macOS, or Windows).
- Better parameter parity amongst tasks.

## Other Changes
- Updated documentation.
- Baselined all task versions.