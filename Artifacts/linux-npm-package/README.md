# NPM Packages #
## Azure DevTest Labs Artifact ##

### Linux NPM Package Manager Artifact ###
This Azure DevTest artifact allows the user to specify packages to install onto an Azure DevTest Lab VM
via the npm package system. The npm package manager must first be installed on the system in some other 
manner, one can use the bash script artifact, the apt artifact for debian-based systems, or the yum artifact
for redhat-based systems.

### Usage ###
The script is intended for use in the Azure DevTest Labs artifact system, and the parameters for the artifact are fed directly
into the script. However, you can run it from any bash shell using the following format:

        bash> .\linux-npm-package.sh -packages (PACKAGE-LIST) --install-to (global|/path/to) --options [ADDITIONAL-OPTIONS]

**Where:**

*packages*

The names of the packages to install, separated by spaces. Each package declaration follows the allowable declarations in npm
install. For example, all the following would work:

        pkgnm githubname/reponame @myorg/privatepackage
        
...please see the [man page for npm](https://docs.npmjs.com/cli/install) for a description of all package reference strings
    
*install-to*

Defaults to global, the 'install-to' parameter tells npm where to install the named packages. This can be the keyword 'global' 
or left blank (default is global) to install to the global location (typically /usr/lib/node_modules on a Linux system). Or the
value can be any valid path (ie. /var/tmp/dev) to install the npm packages into.

*options*

Any other valid arguments that the npm-install command accepts. Since these additional parameters allow for relatively infinite permutations
they will likely be susceptible to failure on the images supplied by the Azure DevTest Labs. Advanced users who wish to push the limitations
of the extra options parameter will potentially have to experiment with certain switches to see if they work (and correct the state of
the VM using the linux-bash artifact ahead of time if necessary).

---

## Tested on images:

- Ubuntu 16.04
- RHEL 7.2
