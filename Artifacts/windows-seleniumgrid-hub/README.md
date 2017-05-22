# Selenium-grid hub

A simple artifact to setup a selenium-grid hub on your azure DevTestLab virtual machine.

## Inputs

- Download link for the selenium standalone server .jar file.
- Optional <a href="https://github.com/SeleniumHQ/selenium/wiki/Grid2#configuring-the-hub-by-json">.json configuration file</a> for the hub.

## Features

- Easy to use with minimal inputs.
- The hub will be brought back up with the last used configuration in case of a system restart or in case the VM is stopped and started again.
- The artifact can be re-applied to the VM to change configuration if necessary.

## Prerequisites

- Currently only Windows OS is supported.
- Java must be installed on the VM (DevTestLabs has an windows-chocolatey installer artifact that can be used to install Java Runtime Environment).

## Limitations

- The hub must be run on the default 4444 port.