
$keyfile = 'C:\junker.txt'

If (Test-Path $keyfile){

    $temp = Get-Content -Path $keyfile

    $key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey("SOFTWARE\Microsoft\Net Framework Setup\NDP\v4\Client",[Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree,[System.Security.AccessControl.RegistryRights]::FullControl)
    $key1033 = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey("SOFTWARE\Microsoft\Net Framework Setup\NDP\v4\Client\1033",[Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree,[System.Security.AccessControl.RegistryRights]::FullControl)

    #Set keys to new value
    $key.SetValue('Release',$temp[0],[Microsoft.Win32.RegistryValueKind]::DWord)
    $key1033.SetValue('Release',$temp[1],[Microsoft.Win32.RegistryValueKind]::DWord)
    $key.SetValue('Version',$temp[2])
    $key1033.SetValue('Version',$temp[3])

    $key.Close()
    $key1033.Close()
    Remove-Item $keyfile
}

