# Linux Yum Package Manager Artifact
This Azure DevTest artifact allows the user to specify packages to install onto their Azure DevTest Lab VM
via the Yum package system. This artifact applies to any Linux distribution that is by default managed by 
the RPM/Yum system (Red Hat, CentOS, and other Red Hat Linux derivatives).

## Usage 
The script is intended for use in the Azure DevTest Labs artifact system, and the parameters for the artifact are fed directly
into the script. However, you can run it from any bash shell using the following format:

        bash> .\linux-yum-package.sh --update (false|true) --packages pkg1 pkg2 pkg3 pkg4 --options *[yum options for install command]*  

**Where:**

*update*

Defaults to false, the 'update' command will be issued before the install command (and optional arguments) are run. For more detailed
control over update arguments, the user will have to specify their own bash script and run that using the linux-bash artifact.

*packages*

The names of the packages to install, separated by spaces. Each package declaration follows the allowable declarations in yum
install. For example, all the following would work:

        pkgnm pkgnm-ver pkgnm-ver-rel.arch -pkgnm @groupnm ^@envgroupname
        
*options*

Any other valid arguments that the yum install command accepts. Since these additional parameters allow for relatively infinite permutations
they will likely be susceptible to failure on the images supplied by the Azure DevTest Labs. Advanced users who wish to push the limiatations
of the extra options parameter will potentially have to experiment with certain switches to see if they work (and correct the state of
the VM using the linux-bash artifact ahead of time if necessary).

> **Note (1):** --assumeyes and --quiet are passed to both the *update* and *install* command by default (and
> cannot be changed).  

> **Note (2):**
> Each comand line parameter has the pattern '--command values' so we can parse the required spaces. As such, there may be some unforeseen
> limitations where double-spaces will be reduced to a single space, and other edge cases that might arise due to its use. If there is a 
> specific use case that doesn't work within this limitation, there is the linux-bash DevTest artifact that will satisfy your needs.

## Notes on yum
Note that yum as a utility is an incredibly flexible and powerful tool. To support the use cases of the more advanced users of
our Linux DevTest Lab VMs, a reasonable effort has been made to support the nuance of the 'install' command. However, due to the vast number of 
permutations and combinations that the command can be used to manipulate the state of a machine, we recommend that for the most advanced
of users with specific needs use the linux-bash artifact to satisfy their specific needs.

For posterity, here is the yum man page section on the install command at the time of authoring this artifact:

---

        install
              Is used to install the latest version of a package or group of
              packages while ensuring that all dependencies are satisfied.
              (See Specifying package names for more information) If no
              package matches the given package name(s), they are assumed to
              be a shell glob and any matches are then installed. If the
              name starts with @^ then it is treated as an environment group
              (group install @^foo), an @ character and it's treated as a
              group (plain group install).

              If the name starts with a "-" character, then a search is done
              within the transaction and any matches are removed. Note that
              Yum options use the same syntax and it may be necessary to use
              "--" to resolve any possible conflicts.

              If the name is a file, then install works like localinstall.
              If the name doesn't match a package, then package "provides"
              are searched (e.g. "_sqlitecache.so()(64bit)") as are
              filelists (Eg. "/usr/bin/yum"). Also note that for filelists,
              wildcards will match multiple packages.

              Because install does a lot of work to make it as easy as
              possible to use, there are also a few specific install
              commands "install-n", "install-na" and "install-nevra". These
              only work on package names, and do not process wildcards etc.
        
        ...
        
        SPECIFYING PACKAGE NAMES

        A package can be referred to for install, update, remove, list, info
        etc with any of the following as well as globs of any of the
        following:

              name
              name.arch
              name-ver
              name-ver-rel
              name-ver-rel.arch
              name-epoch:ver-rel.arch
              epoch:name-ver-rel.arch

              For example: yum remove kernel-2.4.1-10.i686
                   this will remove this specific kernel-ver-rel.arch.

              Or:          yum list available 'foo*'
                   will list all available packages that match 'foo*'. (The
              single quotes will keep your shell from expanding the globs.)

[Source: linux manpages (man7)](http://man7.org/linux/man-pages/man8/yum.8.html)

---

## Tested on images:
 - CentOS 6.5
 - CentOS 6.7
 - RHEL 7.2
 - RHEL 6.7

*Working, but problems (with workarounds) exist:*    
 - CentOS 6.6 - Works without update.
 - CentOS 7.0 - Works without update.
 - CentOS 7.1 - Works without update.
 - CentOS 7.2 - Works without update.
