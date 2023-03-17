Param(
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
$from = "\\fs2\Installs\nAWC12.0.0\0_Development"
$to = "\\QA1-12\wwwroot"

# Set and correct this after Web install build environment set up.
$buildTwoSettings = "\\BuildServer2\Synergis.WebAPI_12.0.0\appsettings.config"  #Set up Future nAWC install build environment and share folder.
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

    Adjust check based on returns encountered.
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

#***************************************************************************
#***********************  COPY ACS TO FS2  *********************************
#***************************************************************************

Write-Host "********** Copying latest ACS to \\fs2... **********"
$acsDirectory = "$source\Adept\ClientServices"

Robocopy $acsDirectory $from\AdeptClientServices /S /IS /Purge /xf AdeptClientServices.vshost* /xd PlugIns ja ru

Write-Host "The ACS copy exited with code: " $LastExitCode
Check-Robocopy -roboreturn $LastExitCode
Write-Host "Post Robocopy return check exit code: " $LastExitCode

Write-Host "********** ACS copied to \\fs2! **********"

#***************************************************************************
#***************  COPY VIEWER SERVER CACHE CLEAR TO FS2  *******************
#***************************************************************************
Write-Host "********** Copy latest Viewer Server Cache Clear utility to Viewer area on \\fs2... **********"
 
Robocopy $source\AdeptWebServer\AdeptClearViewerCache\bin\Release $from\AdeptViewer\Utilities\Cache /S /IS /Purge /xf *.pdb *.xml /xd de es fr-CA it pt-BR

Write-Host "The Viewer Server Config Clean copy exited with code: " $LastExitCode
Check-Robocopy -roboreturn $LastExitCode
Write-Host "Post Robocopy return check exit code: " $LastExitCode

Write-Host "********** Viewer Server Config Clear utility deployed to Viewer area on \\fs2! **********"

<#
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

if(test-path \\fs2\Installs\nAWC12.0.0\0_Development\Synergis.WebViewer\bin\ja)
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
Robocopy $from $to /S /IS /Purge /xf appsettings.config connections.config iisstart.htm welcome.png indexprismdocs.html site_prismdocs.min.css /xd Dynamic aspnet_client jvue AdeptClientServices AdeptViewer AdeptTaskPane Downloads

Write-Host "The QA1 copy exited with code: " $LastExitCode
Check-Robocopy -roboreturn $LastExitCode
Write-Host "Post Robocopy return check: " $LastExitCode

Write-Host "********** Completed copying latest build to QA1:  $(Get-Date) **********"

# Update appsettings.config file...
Write-Host "********** Setting Application Version - QA1 **********"
AppSet-Version -path $qaOneSettings -version $buildNumber

# Restart IIS
Write-Host "********** Restarting IIS... **********"
Invoke-Command -ComputerName QA1-12 -ScriptBlock { Start-Service w3svc } -Credential $credential

#***************************************************************************
#************************  UI TESTING SETUP ********************************
#***************************************************************************

# Reset the UI test level based on time...
Write-Host "********** Checking test type time range... **********"

$RangeStart = "2:45"
$RangeEnd = "6:45"

$now = @(get-date)

If ($now -gt $RangeStart -lt $RangeEnd)
{
    Write-Host "********** Set Nightly Testing Environment Variable for Full Testing... **********"
    Write-Host "##vso[task.setvariable variable=TestType]Nightly"
}
Else
{
    Write-Host "********** Set the CI Testing Environment Variable for CI Buile Testing.. **********"

    # Nightly will be used for full suite testing.
    Write-Host "##vso[task.setvariable variable=TestType]CI" 

    # Trigger for ACS and reporting tasks...
    Write-HOst "##vso[task.setvariable variable=TestCafe]True"
}


# Copy ACS \PlugIns folder from FS2 proior to starting for testing...
Write-Host "********** Copying ACS PlugIns from \\fs2... **********"
Robocopy $from\AdeptClientServices\PlugIns $acsDirectory\PlugIns /S /IS /Purge 

Write-Host "The ACS PlugIns copy exited with code: " $LastExitCode
Check-Robocopy -roboreturn $LastExitCode
Write-Host "Post Robocopy return check exit code: " $LastExitCode
Write-Host "********** ACS PlugIns copied! **********"



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
