Param(
        [string]$buildNumber,
        [string]$source,
        [string]$fileSource, # Pass -fileSource \\fs2\Installs\nAWC12.0.0\0_Development on build step.
        [string]$inclDev
     )

$deploy = $true
$qaTwoSettings = "\\QA2-12\wwwroot\Synergis.WebApi\appsettings.config"
$devOneSettings = "\\DEV-12\wwwroot\Synergis.WebApi\appsettings.config"
$tester = "matt.walker"

# Check Robocopy return codes...
function Check-Robocopy
{
    param ([int] $roboreturn)

    <# This function was added since Robocopy has various return values, which are hashed differently using 
    PowerShell script in vNext builds.
    
    PowerShell Returns:
    0×00   0       No errors occurred, and no copying was done.
                   The source and destination directory trees are completely synchronized. 
    0×01   1       One or more files were copied successfully (that is, new files have arrived).
    0×02   2       Some Extra files or directories were detected. No files were copied
                   Examine the output log for details. 
    0×03   3       (2+1) Some files were copied. Additional files were present. No failure was encountered.
    0×04   4       Some Mismatched files or directories were detected.
                   Examine the output log. Housekeeping might be required.
    0×05   5       (4+1) Some files were copied. Some files were mismatched. No failure was encountered.
    0×06   6       (4+2) Additional files and mismatched files exist. No files were copied and no failures were encountered.
                   This means that the files already exist in the destination directory
    0×07   7       (4+1+2) Files were copied, a file mismatch was present, and additional files were present.
    0×08   8       Some files or directories could not be copied
                   (copy errors occurred and the retry limit was exceeded).
                   Check these errors further.
    0×10  16       Serious error. Robocopy did not copy any files.
                   Either a usage error or an error due to insufficient access privileges
                   on the source or destination directories.
    Adjust logic accordingly based on returns encountered.
    #>

    if (($roboreturn -eq 3) -or ($roboreturn -eq 1)) # Some files copied successfully or new files (ACS)
    {
        $global:LastExitCode = 0
    }
        
}

# Update build and test machine appsettings.config files...
function AppSet-Version
{
    param ([string] $path, [string] $version)

    try
    {        
        [xml] $xml= (Get-Content $path)
        $node = $xml.appSettings.add | where {$_.key -eq 'AppVersion'}
        $node.Value = $version

        $xml.Save($path)
    }
    catch
    {
        Write-Host "Version Set Error!... " + $_.Exception.Message
    }
    
}

# Check the test result files for "failure" and update test servers accordingly...
Get-ChildItem $source\Testing\TestCafe\Scripts\report |
ForEach-Object {
    Write-Host $_.FullName

    $xml = [xml](Get-Content $_.FullName)
    $failures = $xml.testsuite.failures

    if ($failures -ne 0)
    {        
        $deploy = $false
    }
    
    Write-Host "$failures Failures detected in" $_.FullName
}

#if ((Select-String -Path $source\Testing\TestCafe\Scripts\report\report.xml -Pattern 'failures="0"') -ne $null)
if ($deploy = $true)
{
    Write-Host "********** Setting credentials for remote, test server operations... **********"
    $securePassword = ConvertTo-SecureString "3#sdfverM4tt!syner" -AsPlainText -force
    $credential = New-Object System.Management.Automation.PsCredential("ssetestdom\builduser",$securePassword)

    #***************************************************************************
    #***********************  UPDATE QA2/DEV SERVERS  **************************
    #***************************************************************************

    # Stop IIS on QA2, copy files, create Dynamic Models .dll, restazrt IIS, using credential info from above...
    Write-Host "********** Stopping IIS on QA2:  $(Get-Date) **********"
    Invoke-Command -ComputerName QA2-12 -ScriptBlock { stop-service w3svc } -Credential $credential
        
    $to = "\\QA2-12\wwwroot"
    # Dynamic directory excluded as this is built at runtime and was causing permissions errors with Memo info after deletion via machine update.
    # Exclude wwwroot files and directories as well.
    Write-Host "********** Begin copying files from fs2 to QA2:  $(Get-Date) **********"
    #Robocopy $fileSource $to /S /IS /Purge /xf connections.config appsettings.config iisstart.htm welcome.png /xd Dynamic aspnet_client jvue AdeptClientServices Downloads
    Robocopy $fileSource $to /S /IS /Purge /xf connections.config appsettings.config iisstart.htm welcome.png indexprismdocs.html site_prismdocs.min.css /xd Dynamic aspnet_client jvue AdeptClientServices AdeptTaskPane Downloads

    Write-Host "The QA2 copy exited with code: " $LastExitCode      
    Check-Robocopy -roboreturn $LastExitCode
    Write-Host "Post Robocopy return check exit code: " $LastExitCode

    Write-Host "********** Completed copying files from fs2 to QA2:  $(Get-Date) **********"

    # Update QA2 appsettings.config file...
    Write-Host "********** Setting Application Version - QA2 **********"
    AppSet-Version -path $qaTwoSettings -version $buildNumber

    # Restart IIS
    Write-Host "********** Restarting IIS on QA2: $(Get-Date) **********"
    Invoke-Command -ComputerName QA2-12 -ScriptBlock { Start-Service w3svc } -Credential $credential

    Write-Host "Notify of QA2/Dev system readiness..."
    send-mailmessage -to "$tester@synergis.com" -from "$tester@synergis.com" -subject "QA2-12 Updated Successfully" -body "QA2-12 has been updated with the latest code changes (Build: $buildNumber)." -smtpServer mail.synergis.com

    Write-Host "********** QA2 Ready:  $(Get-Date)  **********"

    # Update Dev troubleshooting server...
    if($inclDev -eq 'Y')
    {
        #******************* DEV MACHINE UPDATE  ******************************************
        Write-Host "********** DEV Server IIS Shutting down:  $(Get-Date) **********"
        Invoke-Command -ComputerName DEV-12 -ScriptBlock { stop-service w3svc } -Credential $credential
    
        # Change destination
        $to = "\\DEV-12\wwwroot"

        Write-Host "********** Begin copying files from fs2 to DEV server:  $(Get-Date) **********"
        #Robocopy $fileSource $to /S /IS /Purge /xf connections.config appsettings.config iisstart.htm welcome.png /xd Dynamic aspnet_client jvue AdeptClientServices Downloads
        Robocopy $fileSource $to /S /IS /Purge /xf connections.config appsettings.config iisstart.htm welcome.png indexprismdocs.html site_prismdocs.min.css /xd Dynamic aspnet_client jvue AdeptClientServices AdeptTaskPane Downloads

        Write-Host "The DEV Server copy exited with code: " $LastExitCode      
        Check-Robocopy -roboreturn $LastExitCode
        Write-Host "Post Robocopy return check exit code: " $LastExitCode

        Write-Host "********** Completed copying files from fs2 to the DEV Server:  $(Get-Date) **********"

        Write-Host "********** Setting Application Version - DEV Server **********"
        AppSet-Version -path $devOneSettings -version $buildNumber         

        # Restart IIS
        Write-Host "********** Restarting IIS on Dev Server:  $(Get-Date) **********"
        Invoke-Command -ComputerName DEV-12 -ScriptBlock { Start-Service w3svc } -Credential $credential
        Write-Host "********** DEV Server Ready:  $(Get-Date) **********"
    }
}
else
{
        Write-Host "********** Test failures were detected.  QA/Dev test servers were NOT updated! **********"
}

