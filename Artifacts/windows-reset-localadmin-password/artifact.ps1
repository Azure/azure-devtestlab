[CmdletBinding()]
param
(
    [Parameter(Mandatory=$true)]
    [String] $NewPassword
)

Write-Output "PowerShell $($PSVersionTable.PSVersion)"
function Reset-LocalAdminPassword {
    param(
      [String] $computerName = 'localhost',
      [SecureString] $password
    )
    $adsPath = "WinNT://$computerName,Computer"
    try {
      if ( -not [ADSI]::Exists($adsPath) ) {
        $message = "Cannot connect to the computer '$computerName' because it does not exist."
        $exception = [Management.Automation.ItemNotFoundException] $message
        Write-Output $exception $computerName ObjectNotFound
        throw 'The artifact failed to apply.'
        return
      }
    }
    catch [System.Management.Automation.MethodInvocationException] {
      $message = "Cannot connect to the computer '$computerName' due to the following error: '$($_.Exception.InnerException.Message)'"
      $exception = new-object ($_.Exception.GetType().FullName)($message,$_.Exception.InnerException)
      Write-Output $exception $computerName
      throw 'The artifact failed to apply.'
      return
    }
    $computer = [ADSI] $adsPath
    $localUser = $NULL
    $localUserName = ""
    foreach ( $childObject in $computer.Children ) {
      if ( $childObject.Class -ne "User" ) {
        continue
      }
      $childObjectSID = new-object System.Security.Principal.SecurityIdentifier($childObject.objectSid[0],0)
      if ( $childObjectSID.Value.EndsWith("-500") ) {
        $localUser = $childObject
        $localUserName = $childObject.Name[0]
        break
      }
    }
    try {
      $localUser.SetPassword($password)
      $LocalUser.put("userflags",($LocalUser.UserFlags.value -bxor 0x10000)) #password never expire
      if (($LocalUser.userflags.value -band 0x0002) -as [bool]) {
          $LocalUser.put("userflags", ($LocalUser.userflags.value -bxor 0x0002)) #enable account
      }
      $LocalUser.SetInfo()
      Write-Output "Password for [$localUserName] has been changed and account enabled..."
    }
    catch [System.Management.Automation.MethodInvocationException] {
      $message = "Cannot reset password for '$computerName\$localUserName' due the following error: '$($_.Exception.InnerException.Message)'"
      $exception = new-object ($_.Exception.GetType().FullName)($message,$_.Exception.InnerException)
      Write-Output $exception "$computerName\$localUserName" 
      throw 'The artifact failed to apply.'
    }
  }
  
Reset-LocalAdminPassword -password $NewPassword
