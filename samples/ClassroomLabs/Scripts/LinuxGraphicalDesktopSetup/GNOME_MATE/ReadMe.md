# Introduction
These scripts install GNOME\Xrdp and MATE\X2Go graphical desktop environments on Ubuntu. 

The GNOME and MATE graphical desktop environments have a networking conflict on Ubuntu 18.04 LTS with the Azure Linux Agent which is needed for the VMs to work properly in Azure Lab Services.  For example, this networking conflict will cause lab creation to fail when attempting to provision the template VM.  Likewise, it will cause publish to hang when attempting to provision the student VMs.  To successfully use use GNOME or MATE on lab VMs, the below scripts include additional steps that are required to fix this networking conflict with Ubuntu 18.04 LTS.  This issue is being tracked by the following Canonical bug:  https://bugs.launchpad.net/ubuntu/+source/cloud-init/+bug/1832381.

Other versions of Ubuntu do *not* have this networking conflict with the Azure Linux Agent when you install GNOME or MATE:
- Ubuntu 20.04 LTS and 21.04 LTS with GNOME installed.
- Ubuntu 20.04 LTS with MATE installed.
As a result, when you run the below scripts to install these versions, the steps for fixing the networking conflict are skipped.

## Ubuntu

These scripts have been tested with:
- Ubuntu 18.04 LTS to install GNOME\Xrdp and MATE\X2Go.
- Ubuntu 20.04 LTS and 21.04 to install GNOME\Xrdp.
- Ubuntu 20.04 LTS to install MATE\X2Go.

NOTE: X2Go isn't compatible with GNOME which is why Xrdp must be used.  See X2Go's list of [compatible desktop environments](https://wiki.x2go.org/doku.php/doc:de-compat) for more information.  Also, X2Go packages aren't currently available for Ubuntu 21.04.

## Configuring X2Go and Xrdp

Both [X2Go](https://wiki.x2go.org/doku.php/doc:newtox2go) and [Xrdp](https://en.wikipedia.org/wiki/Xrdp) are Remote Desktop solutions, which sometimes is referred to as Remote Control.  A key difference between X2Go is that it uses the same port as SSH (port 22).  Azure Lab Services enables the SSH port by default. Xrdp uses port 3389 which [you must enable](https://docs.microsoft.com/azure/lab-services/how-to-enable-remote-desktop-linux#enable-remote-desktop-connection-for-rdp) when you create a lab.

X2Go typically provides better performance for students when they need to connect to a Linux VM.  However, X2Go doesn't support all graphical desktops.  As a result, these instructions show using X2Go with MATE and Xrdp with GNOME.

There are two steps involved to set up either X2Go or Xrdp: _(Students only need to do step #2 below to connect to their assigned VM)_

1. [Install the X2Go\Xrdp server](#install-x2go-or-xrdp-server) on the lab's template VM using one of the scripts below.
2. [Install X2Go\RDP client and create a session](#create-x2go-or-rdp-and-create-a-session) to connect to your lab (remote) VM.

### Install X2Go or Xrdp Server

The lab (remote) VM runs either the X2Go or Xrdp server. Graphical sessions are started on this remote VM and the server transfers the windows/desktops graphics to the client.

The scripts below automatically install the X2Go\Xrdp server and the MATE\GNOME graphical desktop environment.  To install using these scripts, SSH into the template VM and paste in one of the following scripts depending on which desktop environment you prefer:

##### Install MATE Desktop & X2Go Server

```bash
sudo sh -c "$(curl -fsSL https://raw.githubusercontent.com/Azure/azure-devtestlab/master/samples/ClassroomLabs/Scripts/LinuxGraphicalDesktopSetup/GNOME_MATE/Ubuntu/x2go-mate.sh)"
```

##### Install GNOME Desktop & Xrdp Server

```bash
sudo sh -c "$(curl -fsSL https://raw.githubusercontent.com/Azure/azure-devtestlab/master/samples/ClassroomLabs/Scripts/LinuxGraphicalDesktopSetup/GNOME_MATE/Ubuntu/xrdp-gnome.sh)"
```

### Install X2Go or RDP Client and Create a Session

Once you have the X2Go\Xrdp server installed on your template VM (using the scripts above), you'll use the X2Go\RDP client to remotely connect to the VM. The X2Go\RDP Client is the application that allows you to connect to a remote server and display a graphical desktop on your local machine.

Read the following articles:
 - [Connect to student VM using X2Go](https://docs.microsoft.com/azure/lab-services/how-to-use-remote-desktop-linux-student#connect-to-the-student-vm-using-x2go)
 - [Connect to student VM using RDP](https://docs.microsoft.com/azure/lab-services/how-to-use-remote-desktop-linux-student#connect-to-the-student-vm-using-microsoft-remote-desktop-rdp)
