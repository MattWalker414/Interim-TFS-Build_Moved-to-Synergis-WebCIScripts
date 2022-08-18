Param(
        [string]$uiType, 
        [string]$inclDev,
        [string]$source,
        [string]$buildNumber,
        [string]$acsURLProtocolPath
     )

$bldType = "Release"

Write-Host "**********Postbuild script started:  $(Get-Date) **********"

#***************************************************************************
#*******************  VERSION SPECIFIC INFORMATION  ************************
#***************************************************************************

$msbuild = """C:\Program Files (x86)\Microsoft Visual Studio\2019\Professional\MSBuild\Current\Bin\MSBuild.exe"""
$mstest = "C:\Program Files (x86)\Microsoft Visual Studio\2019\Professional\Common7\IDE\mstest.exe"
$mstf = "C:\Program Files (x86)\Microsoft Visual Studio\2019\Professional\Common7\IDE\CommonExtensions\Microsoft\TeamFoundation\Team Explorer\tf.exe"

#***************************************************************************
#*************************  QA INFORMATION  ********************************
#***************************************************************************

$tester = "Matt.Walker"
#$tester1 = "Paul.Ligowski"
#$tester2 = "Ursula.Miles"
#$tester3 = "Steve.Ackerman"
#$tester4 = "Rashmi.Chinnawar"

# Test Server Deployment information...
$from = "\\fs2\Installs\nAWC12.0.0_Git\0_Development"
$to = "\\QA1-12\wwwroot"

# Set and correct this after Web install build environment set up.
$buildTwoSettings = "\\BuildServer2\Synergis.WebAPI_12.0.0_Git\appsettings.config"  #Set up Future nAWC install build environment and share folder.
$qaOneSettings = "\\QA1-12\wwwroot\Synergis.WebApi\appsettings.config"
$qaTwoSettings = "\\QA2-12\wwwroot\Synergis.WebApi\appsettings.config"
$devOneSettings = "\\DEV-12\wwwroot\Synergis.WebApi\appsettings.config"
#$orclTwoSettings = "\\WIN2K12R2-OR19\wwwroot\Synergis.WebApi\appsettings.config"

$urlSQL = "http://QA1-12/Synergis.WebApp"

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


<#  ADD WHEN VERSIONING ADDED...
#***************************************************************************
#*******************  UNDO AssemblyInfo VERSIONING  ************************
#***************************************************************************
Write-Host "********** Undoing Assembly versioning... **********"
$pathToSearch = $source + "\Development\12.0\Web\AdeptWeb"
cd $pathToSearch
&"$mstf" undo /recursive $pathToSearch AssemblyInfo.*
Write-Host "********** AdeptWeb Assembly versioning undone! **********"

$pathToSearch = $source + "\Development\12.0\Web\AdeptWebTaskPane\AdeptClientServices"
cd $pathToSearch
&"$mstf" undo /recursive $pathToSearch AssemblyInfo.*
Write-Host "********** ACS Assembly versioning undone! **********"
#>

#  Update Install Build appsettings.config file...
Write-Host "********** Setting Application Version - Build2 **********"
AppSet-Version -path $buildTwoSettings -version $buildNumber
Write-Host "********** Application Version - Build2 set! **********"


<# ADD WHEN ACS FINALIZED AND ADDED TO GIT
#***************************************************************************
#***********************  COPY ACS TO FS2  *********************************
#***************************************************************************

Write-Host "********** Copying latest ACS to \\fs2... **********"
# ACS builds to one folder above $source so strip the last or actual source directory from string...
#$acsDirectory = $source.Substring(0, $source.LastIndexOf("\")) + "\Program Files\Synergis\AdeptClientServices"
$acsDirectory = $acsURLProtocolPath + "\Program Files\Synergis\AdeptClientServices"

Robocopy $acsDirectory $from\AdeptClientServices /S /IS /Purge /xf AdeptClientServices.vshost* /xd PlugIns ja ru

Write-Host "The ACS copy exited with code: " $LastExitCode
Check-Robocopy -roboreturn $LastExitCode
Write-Host "Post Robocopy return check exit code: " $LastExitCode

Write-Host "********** ACS copied to \\fs2! **********"

#***************************************************************************
#*******************  COPY BUILDABLE PLUGINS TO FS2  ***********************
#***************************************************************************
Write-Host "********** Copying Buildable ACS PlugIns  to \\fs2... **********"
$acsPlugIns = $acsURLProtocolPath + "\Program Files\Synergis\AdeptClientServices\PlugIns"

Robocopy $acsPlugIns $from\AdeptClientServices\PlugIns AP_*.dll
Write-Host "Main .dlls copied."

Robocopy $acsPlugIns $from\AdeptClientServices\PlugIns TallComponents.PDF*.dll

Write-Host "The ACS Plugin copy exited with code: " $LastExitCode
Check-Robocopy -roboreturn $LastExitCode
Write-Host "Post Robocopy return check exit code: " $LastExitCode

Write-Host "********** Buildable ACS PlugIns copied to \\fs2! **********"
#>

#***************************************************************************
#*******************  UPDATE TEST  SERVER  *********************************
#***************************************************************************

<# LANGUAGES SHOULD BE FILTERED OUT THROUGH COMPILE...
# Remove the Japanese and Russian Viewer \bin subfolders as those languages
# not supported...
Write-Host "********** Checking for unsupported languages in Viewer \bin folder... **********"

if(test-path \\fs2\Installs\nAWC12.0.0_Git\0_Development\Synergis.WebViewer\bin\ja)
{
    Remove-Item -path \\fs2\Installs\nAWC12.0.0\0_Development\Synergis.WebViewer\bin\ja -recurse
}

if(test-path \\fs2\Installs\nAWC12.0.0\0_Development\Synergis.WebViewer\bin\ru)
{
    Remove-Item -path \\fs2\Installs\nAWC12.0.0\0_Development\Synergis.WebViewer\bin\ru -recurse
}

Write-Host "********** Check and remove of unused languages in the viewer completed. **********"
#>

Write-Host "********** Setting credentials for remote, test server operations... **********"

# Stop then later restart the Test Server site due to issues copying PrecompiledApp.config
# Stop/start didn't seem to work so trying iisrestart
$securePassword = ConvertTo-SecureString "3#sdfverM4tt!syner" -AsPlainText -force
$credential = New-Object System.Management.Automation.PsCredential("ssetestdom\builduser",$securePassword)

Write-Host "********** Remote operations credentials set. **********"

Write-Host "********** IIS Shutting down... **********"
Invoke-Command -ComputerName QA1-12 -ScriptBlock { stop-service w3svc } -Credential $credential

# Three sub-directories will be copied to \\fs2\Installs\nAWC\0_Development.
# Copy to \\INFINITY-FUTURE\Synergis
# /S = Copy subfolders
# /IS = Include Same, overwrite files even if they are already the same.
# /Purge = Delete dest files/folders that no longer exist in source.
# /xf = Exclude Files matching given names/paths/wildcards

# Had to add my credentials to the Synergis directory (in addition to the share of that directory).
# Dynamic directory excluded as this is built at runtime and was causing permissions errors with Memo info after deletion via machine update.
# Exclude wwwroot files and directories as well.
# Exclude White Label related files (indexprismdocs.html/site_prismdocs.min.css) from push to QA1.  Other test servers should receive these types of files.

Write-Host "********** Begin copying latest build to QA1:  $(Get-Date) **********"
Robocopy $from $to /S /IS /Purge /xf connections.config appsettings.config iisstart.htm welcome.png indexprismdocs.html site_prismdocs.min.css /xd Dynamic aspnet_client jvue AdeptClientServices AdeptTaskPane Downloads

Write-Host "The QA1 copy exited with code: " $LastExitCode
Check-Robocopy -roboreturn $LastExitCode
Write-Host "Post Robocopy return check: " $LastExitCode

Write-Host "********** Completed copying latest build to QA1:  $(Get-Date) **********"


# Update appsettings.config file...
Write-Host "********** Setting Application Version - QA1 **********"
AppSet-Version -path $qaOneSettings -version $buildNumber

<#  ADDRESS LATER...
# Create the Dynamic Model .dll on the REMOTE test server (QA1)
Write-Host "********** Creating Dynamic Model .dll on Test Server **********"

# Change directory to WebApi\bin for correct output from .exe...
$remoteScript = {
                    cd C:\inetpub\wwwroot\Synergis.WebApi\bin
                    C:\inetpub\wwwroot\Synergis.WebApi\bin\Synergis.DynamicModelConsole.exe -output C:\inetpub\wwwroot\Synergis.webAPI\bin\
                }

Invoke-Command -ComputerName QA1-12 -ScriptBlock $remoteScript -Credential $credential
Write-Host "********** Dynamic Model .dll created successfully on QA1 **********"
#>

# Restart IIS
Write-Host "********** Restarting IIS... **********"
Invoke-Command -ComputerName QA1-12 -ScriptBlock { Start-Service w3svc } -Credential $credential
 

#***************************************************************************
#*******************  UI TESTING  ******************************************
#***************************************************************************

# No need to remove the TestCafe report file as that will be removed or cleared with each build.

# Reset the UI test level based on time...
Write-Host "********** Checking test type time range... **********"

$RangeStart = "5:00"
$RangeEnd = "9:00"

$now = @(get-date)


If ($now -gt $RangeStart -lt $RangeEnd)
{
    $uiType = "Full"
    Write-Host "********** Running FULL test suite... **********"
}
Else
{
    Write-Host "********** Running Basic, log in/out test... **********"
}

<# UNCOMENT WHEN ACS INCLUDED IN/PULLED AND BUILT FROM GIT REPO...
# Copy ACS \PlugIns folder from FS2 proior to starting for testing...
Write-Host "********** Copying ACS PlugIns from \\fs2... **********"
Robocopy $from\AdeptClientServices\PlugIns $acsDirectory\PlugIns /S /IS /Purge 

Write-Host "The ACS PlugIns copy exited with code: " $LastExitCode
Check-Robocopy -roboreturn $LastExitCode
Write-Host "Post Robocopy return check exit code: " $LastExitCode
Write-Host "********** ACS PlugIns copied! **********"
#>

# Run the UI tests...

Write-Host "********** Executing UI Tests **********"
#***************************************************************************
#********** Adjust here to run only login pending UI Test rework *********** 
#***************************************************************************
if($uiType -eq 'Basic')
{
    # Selenium
    #&"$mstest" "/testcontainer:$source\Development\12.0\Web\AdeptWeb\Synergis.SeleniumUITest\Synergis.SeleniumUITest\bin\$bldType\Synergis.SeleniumUITest.dll" "/test:TestLoginOut" "/resultsfile:$xmlpath" | Out-File $resultsSummary    
    
    #***************************************************************************
    #******************************** Test Cafe ******************************** 
    #***************************************************************************

    # Set to run test and publish test report if Basic UI tests running for now...
    # Nightly will be used for full suite testing.
    Write-Host "##vso[task.setvariable variable=TestType]CI" 

    # Trigger for ACS and reporting tasks...
    Write-HOst "##vso[task.setvariable variable=TestCafe]True"
    
}
else
{   
    

    # Run the full suite of tests...


    <# RE-EVALUATE THE NEED FOR STOPPING ACS AFTER CLIENT SERVICES ADDED AND BUILDING
    # Stop ACS
    Write-Host "********** Terminating Client Services... **********"
    &"$acsDirectory\TerminateCS.exe"
    #>
}

<# REWORK WHEN READY FOR TESTCAFE TESTING...
Write-Host "********** Test execution complete! **********"

# If failure, let me know...
if($testresult -eq 'Failed')
{  
    # Send and Selenium Test errors and attach output file...
    Write-Host "********** UI Test(s) failed! **********"

    if($uiType -eq 'Full')
    {
        # Get summary information for email body and preserve formatting...
        $filecontents = [string]::Join("`r`n",(get-content -path $resultsSummary))

        # Notify wider QA group since QA2 will not be updated...
        #send-mailmessage -to "$tester@synergis.com", "$tester2@synergis.com", "$tester3@synergis.com", "$tester4@synergis.com" -from "$tester@synergis.com" -subject "12.0.0 UI Tests Failed (QA2 NOT Updated!)" -body "$filecontents" -smtpServer mail.synergis.com -Attachments "$testLog"
        
        # Vacation recipients...
        #send-mailmessage -to "$tester@synergis.com", "$tester1@synergis.com" -from "$tester@synergis.com" -subject "12.0.0 UI Tests Failed (QA2 NOT Updated!)" -body "$filecontents" -smtpServer mail.synergis.com -Attachments "$testLog"
        send-mailmessage -to "$tester@synergis.com" -from "$tester@synergis.com" -subject "12.0.0 UI Tests Failed (QA2 NOT Updated!)" -body "$filecontents" -smtpServer mail.synergis.com -Attachments "$testLog"
    }
    #else  # Not needed with TestCafe at this time.
    #{
    #    send-mailmessage -to "$tester@synergis.com" -from "$tester@synergis.com" -subject "Release $uiType 12.0.0 UI Test(s) Failed" -body "$filecontents" -smtpServer mail.synergis.com -Attachments "$testLog"        
    #}

    Write-Host "********** Test failure notification sent! **********"
    
}
else
{
    Write-Host "********** UI Test(s) Completed:  $(Get-Date) **********"
    
    if($uiType -eq 'Full')
    {
        #***************************************************************************
        #*********************  UPDATE QA2/ORACLE SERVERS  *************************
        #***************************************************************************

        # Stop IIS on QA2, copy files, create Dynamic Models .dll, restazrt IIS, using credential info from above...
        Write-Host "********** Stopping IIS on QA2:  $(Get-Date) **********"
        Invoke-Command -ComputerName QA2-12 -ScriptBlock { stop-service w3svc } -Credential $credential
        
        $to = "\\QA2-12\wwwroot"
        # Dynamic directory excluded as this is built at runtime and was causing permissions errors with Memo info after deletion via machine update.
        # Exclude wwwroot files and directories as well.
        Write-Host "********** Begin copying files from fs2 to QA2:  $(Get-Date) **********"
        #Robocopy $from $to /S /IS /Purge /xf connections.config appsettings.config iisstart.htm welcome.png /xd Dynamic aspnet_client jvue AdeptClientServices Downloads
        Robocopy $from $to /S /IS /Purge /xf connections.config appsettings.config iisstart.htm welcome.png indexprismdocs.html site_prismdocs.min.css /xd Dynamic aspnet_client jvue AdeptClientServices AdeptTaskPane Downloads

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

        #send-mailmessage -to "$tester@synergis.com", "$tester2@synergis.com", "$tester3@synergis.com", "$tester4@synergis.com" -from "$tester@synergis.com" -subject "QA2-12 Updated Successfully" -body "QA2-12 has been updated with the latest code changes (Build: $buildNumber)." -smtpServer mail.synergis.com -Attachments "$testLog"
        send-mailmessage -to "$tester@synergis.com" -from "$tester@synergis.com" -subject "QA2-12 Updated Successfully" -body "QA2-12 has been updated with the latest code changes (Build: $buildNumber)." -smtpServer mail.synergis.com -Attachments "$testLog"

        Write-Host "********** QA2 Ready:  $(Get-Date)  **********"

        #  Update Install Build appsettings.config file...
        Write-Host "********** Setting Application Version on Install Build Server **********"
        AppSet-Version -path $buildTwoSettings -version $buildNumber

        # Update Dev troubleshooting server...
        if($inclDev -eq 'Y')
        {
            #******************* DEV MACHINE UPDATE  ******************************************
            Write-Host "********** DEV Server IIS Shutting down:  $(Get-Date) **********"
            Invoke-Command -ComputerName DEV-12 -ScriptBlock { stop-service w3svc } -Credential $credential
    
            # Change destination
            $to = "\\DEV-12\wwwroot"

            Write-Host "********** Begin copying files from fs2 to DEV server:  $(Get-Date) **********"
            #Robocopy $from $to /S /IS /Purge /xf connections.config appsettings.config iisstart.htm welcome.png /xd Dynamic aspnet_client jvue AdeptClientServices Downloads
            Robocopy $from $to /S /IS /Purge /xf connections.config appsettings.config iisstart.htm welcome.png indexprismdocs.html site_prismdocs.min.css /xd Dynamic aspnet_client jvue AdeptClientServices AdeptTaskPane Downloads

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
    
 }

 #>


# If full UI tests were run, restore database on -QA1-12...
if($uiType -eq 'Full')
{
    #***************************************************************************
    #********************  CLEANUP  (Restoration Utility) **********************
    #***************************************************************************

    <# USE THIS RESTORE IF CLEANUP/ENVIRON. RESET UTILITY IS PROBLEMATIC.  DELETE OTHERWISE...
    Write-Host "********** Restoring Db on QA1-12:  $(Get-Date) **********"
    Invoke-Command -ComputerName QA1-12 -ScriptBlock { Invoke-SqlCmd "USE [master]; ALTER DATABASE [AdeptDatabase] SET  SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [AdeptDatabase]" } -Credential $credential
    Invoke-Command -ComputerName QA1-12 -ScriptBlock { Restore-SqlDatabase -ServerInstance QA1-12 -Database AdeptDatabase -BackupFile "C:\DbBackup\AdeptDatabase.bak" } -Credential $credential
    #Write-Host "********** Db Restore Status: $Error **********"

    Write-Host "********** Db restored! **********"  
    #>
}
Else
{
    Write-Host "********** No Db restore after Basic tests. **********"

    # Going to star from a scripted .bat file launched before tests from Build Definition
    #Write-Host "************ Starting ACS for TestCafe ***************"
    #&"$acsDirectory\AdeptClientServices.exe" start
}



# Script build step erroring during Full build after Db restore.  Show latest error encountered.
 Write-Host "Number of errors detected:" $Error.Count

if ($Error.Count -gt 0)
{
    Write-Host "The latest error encountered is as follows:"
    Write-Host $Error[0]
}

#***************************************************************************
#**********************  Adept Task Pane ***********************************
#***************************************************************************

#$atpDirectory = "$source\AdeptNet\AdeptNet2.1\AdeptWebTaskPane\TaskPane\bin\Release"

## Copy to \\fs2...
#Robocopy $atpDirectory $from\AdeptTaskPane /S /IS /Purge /xf *.xml AdeptWebTaskPane.vshost* AdeptTP.chm /xd PlugIns ru ja

#Write-Host "The ATP copy exited with code: " $LastExitCode      
#Check-Robocopy -roboreturn $LastExitCode
#Write-Host "Post Robocopy return check exit code: " $LastExitCode

Write-Host "The Deployment & Testing script returned" $LastExitCode
