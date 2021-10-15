# Introduction
These scripts install the X2Go server for the selected Linux desktop environment (XFCE4 or Xubuntu) on your Linux lab VM.  

## Ubuntu

These scripts work for both 16.04 LTS and 18.04 LTS.  They will likely work for other versions, but are untested.

## Configuring X2Go

[X2Go](https://wiki.x2go.org/doku.php/doc:newtox2go) is a Remote Desktop solution, which sometimes is referred to as Remote Control. This is not to be confused with Microsoft Remote Desktop Connection that uses RDP - this is a competing Remote Desktop solution and protocol.

Using X2Go requires two steps: _(Students only need to do step #2 below to connect to their assigned VM)_

1. [Install the X2Go server](#install-x2go-server) on the lab's template VM using one of the scripts below.
2. [Install the X2Go client and create a session](#create-x2go-client-and-create-session) to connect to your lab (remote) VM.

### Install X2Go Server

The lab (remote) VM runs X2Go server. Graphical sessions are started on this remote VM and the server transfers the windows/desktops graphics to the client.

The scripts below automatically install the X2Go server and the Linux desktop environment.  To install using these scripts, SSH into the template VM and paste in one of the following scripts depending on which desktop environment you prefer:

##### Install XFCE4 Desktop & X2Go Server

```bash
sudo sh -c "$(curl -fsSL https://raw.githubusercontent.com/Azure/azure-devtestlab/master/samples/ClassroomLabs/Scripts/LinuxGraphicalDesktopSetup/XFCE_Xubuntu/Ubuntu/x2go-xfce4.sh)"
```

##### Install Xubuntu Desktop & X2Go Server

```bash
sudo sh -c "$(curl -fsSL https://raw.githubusercontent.com/Azure/azure-devtestlab/master/samples/ClassroomLabs/Scripts/LinuxGraphicalDesktopSetup/XFCE_Xubuntu/Ubuntu/x2go-xubuntu.sh)"
```

### Install X2Go Client and Create a Session

Once you have the X2Go\Xrdp server installed on your template VM (using the scripts above), you'll use the X2Go\RDP client to remotely connect to the VM. The X2Go\RDP Client is the application that allows you to connect to a remote server and display a graphical desktop on your local machine.

Read the following article:
 - [Connect to student VM using X2Go](https://docs.microsoft.com/azure/lab-services/how-to-use-remote-desktop-linux-student#connect-to-the-student-vm-using-x2go)

