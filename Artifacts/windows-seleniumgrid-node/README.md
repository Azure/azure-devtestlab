# Selenium-grid node

A simple artifact to setup a selenium-grid node on your azure DevTestLab virtual machine.

## Inputs

- Download link for the selenium standalone server .jar file.
- IP address or FQDN of the machine on which the selenium-grid hub is running on.
- Optional <a href="https://github.com/SeleniumHQ/selenium/wiki/Grid2#configuring-the-nodes-by-json">.json configuration file</a> for the node.

## Features

- Easy to use with minimal inputs.
- The node will be brought back up with the last used configuration in case of a system restart or in case the VM is stopped and started again.
- The artifact can be re-applied to the VM to change configuration if necessary.
- The artifact adds the folder where the windows-selenium artifact installs the drivers to the system PATH variable. 

## Prerequisites

- Currently only Windows OS is supported.
- Java must be installed on the VM (DevTestLabs has an windows-chocolatey installer artifact that can be used to install Java Runtime Environment).
- Any necessary browsers and drivers must be pre-installed on the VM (DevTestLabs has a windows-selenium artifact that installs browsers and necessary drivers).