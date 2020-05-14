# Introduction
These scripts install the X2Go server for the selected Linux desktop environment (MATE, XFCE4, or Xubuntu) on your Linux lab VM.  

A script is also provided for installing the X2Go client on the local machine that is used to connect to the lab VM.

## Ubuntu

These scripts work for both 16.04 LTS and 18.04 LTS.  They will likely work for other versions, but are untested.

## Configuring X2Go

[X2Go](https://wiki.x2go.org/doku.php/doc:newtox2go) is a Remote Desktop solution, which sometimes is referred to as Remote Control. This is not to be confused with Microsoft Remote Desktop Connection that uses RDP - this is a competing Remote Desktop solution and protocol.

Using X2Go requires three steps: _(Students only need to do step #2 and #3 below to connect to their assigned VM)_

1. [Install the X2Go server](#install-x2go-server) on the lab's template VM using one of the three scripts below.
2. [Install the X2Go client](#install-x2go-client) software on your local machine to connect to the lab (remote) VM.
3. [Create an X2Go session](#create-x2go-session) in the X2Go client to connect to your lab (remote) VM.

### Install X2Go Server

The lab (remote) VM runs X2Go server. Graphical sessions are started on this remote VM and the server transfers the windows/desktops graphics to the client.

The scripts below automatically install the X2Go server and the Linux desktop environment.  To install using these scripts, SSH into the template VM and paste in one of the following scripts depending on which desktop environment you prefer:

##### Install MATE Desktop & X2Go Server

```bash
sudo sh -c "$(curl -fsSL https://raw.githubusercontent.com/colbylwilliams/lab-scripts/master/ubuntu/x2go-mate.sh)"
```

##### Install XFCE4 Desktop & X2Go Server

```bash
sudo sh -c "$(curl -fsSL https://raw.githubusercontent.com/colbylwilliams/lab-scripts/master/ubuntu/x2go-xfce4.sh)"
```

##### Install Xubuntu Desktop & X2Go Server

```bash
sudo sh -c "$(curl -fsSL https://raw.githubusercontent.com/colbylwilliams/lab-scripts/master/ubuntu/x2go-xubuntu.sh)"
```

### Install X2Go Client

Once you have the X2Go server installed on your template VM (using the scripts above), you'll use the X2Go client to remotely connect to the VM. The X2Go Client is the application that allows you to connect to a remote server and display a graphical desktop on your local machine.

**Instructions for installing the X2Go client can be found [here](https://wiki.x2go.org/doku.php/doc:installation:x2goclient).**

Once you've installed the X2Go client, you'll need to **create a new session** to connect to your lab VM.

### Create X2Go Session

First, you'll need to get the connection details for your lab VM:

- **Instructors** (template) VM: Go to the [Lab Services portal](https://labs.azure.com/), select your Lab, select **_Customize template_** on the _Template_ tab, then select **_SSH_**
- **Students**: Go to the [Lab Services portal](https://labs.azure.com/virtualmachines), select the **_Connect_** icon on your Lab VM, then select **_SSH_** (note: you may need to start your VM if it isn't already running)

The connection details will look something like this:

```bash
ssh -p 12345 student@ml-lab-00000000-0000-0000-0000-000000000000.eastus2.cloudapp.azure.com
```

Once you have these connection details, open the X2Go client app and **create a new Session**.

Fill in the following values in the Session Preferences pane _(replacing the values from the example above with the values from your own connection details)_:

- **Session name**: Specify a name; we recommend using the name of your lab VM
- **Host**: `ml-lab-00000000-0000-0000-0000-000000000000.eastus2.cloudapp.azure.com`
- **Login**: `student`
- **SSH port**: `12345`
- **Session type**: Select `MATE` or `XFCE` depending on which Desktop/script you installed. _(If you chose Xubuntu, select `XFCE`)_
- **Select _OK_.**
