# Linux Apt Package Manager Artifact
This Azure DevTest artifact allows the user to specify packages to install onto an Azure DevTest Lab VM
via the apt-get package system. This artifact applies to any Linux distribution that is by default managed 
by the Apt system (Debian, Ubuntu, and other Debian derivatives) or that has had apt set up on it.

## Usage 
The script is intended for use in the Azure DevTest Labs artifact system, and the parameters for the artifact are fed directly
into the script. However, you can run it from any bash shell using the following format:

        bash> .\linux-apt-package.sh --update (false|true) --packages pkg1 pkg2 pkg3 pkg4 --options [-asqdyfmubV] [-o=config_string] [-c=config_file] [-t=target_release] [-a=architecture]  

**Where:**

*update*

Defaults to false, the 'update' command will be issued before the install command (and optional arguments) are run. For more detailed
control over update arguments, the user will have to specify their own bash script and run that using the linux-bash artifact.

*packages*

The names of the packages to install, separated by spaces. Each package declaration follows the allowable declarations in apt-get
install. For example, all the following would work:

        pkgnm/targetdistroversion pkgnm/testing pkgnm/unstable -pkgnm +pkgnm ^pkgnmprefix.* pkgnm=version
        
*options*

Any other valid arguments that the apt-get command accepts. Since these additional parameters allow for relatively infinite permutations
they will likely be susceptible to failure on the images supplied by the Azure DevTest Labs. Advanced users who wish to push the limiatations
of the extra options parameter will potentially have to experiment with certain switches to see if they work (and correct the state of
the VM using the linux-bash artifact ahead of time if necessary).

> **Note (1):** --assume-yes and --quiet are passed to both the *update* and *install* command by default (and
> cannot be changed).  

> **Note (2):**
> Each comand line parameter has the pattern '--command values' so we can parse the required spaces. As such, there may be some unforeseen
> limitations where double-spaces will be reduced to a single space, and other edge cases that might arise due to its use. If there is a 
> specific use case that doesn't work within this limitation, there is the linux-bash DevTest artifact that will satisfy your needs.

## Notes on apt-get
Note that apt-get as a utility is an incredibly flexible and powerful tool. To support the use cases of the more advanced users of
our Linux DevTest Lab VMs, a reasonable effort is made to support the nuance of the 'install' command. However, due to the vast number of 
permutations and combinations that the command can be used to manipulate the state of a machine, we recommend that for the most advanced
of users with specific needs use the linux-bash artifact to satisfy their specific needs.

Please see [debian manpages on apt-get](http://manpages.debian.org/cgi-bin/man.cgi?query=apt-get) for further details on what can be 
specified for apt-get packages and additional options. 

---

## Tested on images:

- Debian 7 "Wheezy"
- Debian 8 "Jessie"
- Ubuntu 12.04.5
- Ubuntu 14.04 
- Ubuntu 15.10
- Ubuntu 16.04
