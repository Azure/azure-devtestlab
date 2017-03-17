

Function Get-RedirectedUrl
{
    Param (
        [Parameter(Mandatory=$true)]
        [String]$URL
    )
 
    $request = [System.Net.WebRequest]::Create($url)
    $request.AllowAutoRedirect=$false
    $response=$request.GetResponse()
 
    If ($response.StatusCode -eq "MovedPermanently")
    {
        $response.GetResponseHeader("Location")
    }
}

$seleniumServerURL = Get-RedirectedUrl -URL 'https://goo.gl/uTXEJ1'

$seleniumServerJAR = "$env:ProgramFiles\Selenium Server\seleniumserver.jar"



try
{
   $dlFile =  (New-Object System.Net.WebClient).DownloadFile($seleniumServerURL,"${env:Temp}\seleniumserver.jar" )
    
    new-Item -Path "$env:ProgramFiles\Selenium Server\" -ItemType Directory -Force
    Move-Item  -Path "${env:Temp}\seleniumserver.jar" -Destination $seleniumServerJAR 
}
catch
{
    Write-Error "Failed to download Selenium Server"
}

try
{
  
  
    # Create Startup Items
 

        New-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "Selenium Hub" -Value  ('java -jar "' + $seleniumServerJAR +'"  -role hub') -PropertyType "String" 
           New-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "Selenium Node" -Value  ('java -jar "' + $seleniumServerJAR +'"  -role node  -hub http://localhost:4444/grid/register') -PropertyType "String" 

Start-Process 'java' -ArgumentList ('-jar "' + $seleniumServerJAR +'"  -role hub')
Start-Process 'java' -ArgumentList ('-jar "' + $seleniumServerJAR +'"  -role node -hub http://localhost:4444/grid/register')
 
 
}
catch
{
    Write-Error 'Failed to create reg entries and start Selenium Server '
}

try{

# open ports

New-NetFirewallRule -DisplayName 'Selenium' -Profile @('Domain', 'Private') -Direction Inbound -Action Allow -Protocol TCP -LocalPort @('4444')

}
catch
{

 Write-Error 'Failed to open firewall ports for Selenium Server'

}

