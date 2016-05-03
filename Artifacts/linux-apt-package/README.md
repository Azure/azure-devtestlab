# Linux APT Package Manager Artifact
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

For posterity, here is the apt-get man page section on the install command at the time of authoring this artifact:

---

> install
>
> install is followed by one or more packages desired for installation or upgrading. Each package is a package name, not a fully qualified filename (for instance, in a Debian system,
> apt-utils would be the argument provided, not apt-utils_1.0.9.8.3_amd64.deb). All packages required by the package(s) specified for installation will also be retrieved and
> installed. The /etc/apt/sources.list file is used to locate the desired packages. If a hyphen is appended to the package name (with no intervening space), the identified package
> will be removed if it is installed. Similarly a plus sign can be used to designate a package to install. These latter features may be used to override decisions made by apt-get's
> conflict resolution system.
> 
> A specific version of a package can be selected for installation by following the package name with an equals and the version of the package to select. This will cause that version
> to be located and selected for install. Alternatively a specific distribution can be selected by following the package name with a slash and the version of the distribution or the
> Archive name (stable, testing, unstable).
> 
> Both of the version selection mechanisms can downgrade packages and must be used with care.
> 
> This is also the target to use if you want to upgrade one or more already-installed packages without upgrading every package you have on your system. Unlike the "upgrade" target,
> which installs the newest version of all currently installed packages, "install" will install the newest version of only the package(s) specified. Simply provide the name of the
> package(s) you wish to upgrade, and if a newer version is available, it (and its dependencies, as described above) will be downloaded and installed.
> 
> Finally, the apt_preferences(5) mechanism allows you to create an alternative installation policy for individual packages.
> 
> If no package matches the given expression and the expression contains one of '.', '?' or '*' then it is assumed to be a POSIX regular expression, and it is applied to all package
> names in the database. Any matches are then installed (or removed). Note that matching is done by substring so 'lo.*' matches 'how-lo' and 'lowest'. If this is undesired, anchor the
> regular expression with a '^' or '$' character, or create a more specific regular expression.
> 
[Source: debian manpages](http://manpages.debian.org/cgi-bin/man.cgi?query=apt-get)

---

## Tested on images:

- Debian 7 "Wheezy"
- Debian 8 "Jessie"
- Ubuntu 12.04.5
- Ubuntu 14.04 
- Ubuntu 15.10
- Ubuntu 16.04
