[cmdletbinding()]
Param()
Import-Module $PSScriptRoot\..\Az.LabServices.psm1

. $PSScriptRoot\Utils.ps1

$la = Get-FastLabAccount
$sg = Get-FastGallery

$mtx = New-Object System.Threading.Mutex($false, "231db620-9fec-4a20-86dd-31812d055325")

# This is an example where I can't think of a way to make the test multi-thread safe without using a mutex
Describe 'Shared Gallery Management' {
    It 'Can attach/detach a shared library' {

        try {
            if($mtx.WaitOne(60 * 60 * 1000)) {
                # We have the mutex. Move on to main logic after the catch clause.
            } else {
                $false | Should -BeTrue -Because "Can't get the mutex before timing out"
            }

        } catch [System.Threading.AbandonedMutexException] {
            # This means a previous test crashed before releasing the mutex, trying to bring the lab in the correct initial state
            $la | Remove-AzLabAccountSharedGallery -SharedGalleryName $sg.Name
        }
            
        $sg | Should -Not -Be $null

        $acsg = $la | New-AzLabAccountSharedGallery -SharedGallery $sg
        $acsg | Should -Not -Be $null

        $imgs = $la | Get-AzLabAccountSharedImage
        $imgs.Count | Should -BeGreaterThan 0

        $la | Remove-AzLabAccountSharedGallery -SharedGalleryName $sg.Name
        $mtx.ReleaseMutex()  
    }    
}
