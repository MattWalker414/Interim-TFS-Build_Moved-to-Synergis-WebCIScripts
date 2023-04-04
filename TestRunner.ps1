Param(
        [string]$source,
        [string]$configPath
     )

# Test areas to cycle through based Database name for the connection and folder name for tests (Database.Folder)...
[string[]]$funcArea = "Checkout.check-out" #, "NextTestArea.NextFolder

$securePassword = ConvertTo-SecureString "3#sdfverM4tt!syner" -AsPlainText -force
$credential = New-Object System.Management.Automation.PsCredential("ssetestdom\builduser",$securePassword)

$testCafeDir = "$source\Testing\TestCafe\Scripts"

cd $testCafeDir

foreach ($test in $funcArea)
{
    $info = $test.split('.')
    $database = $info[0]
    $folder = $info[1]

    # Edit the config file with database name...
    Write-Host "********** IIS Shutting down for config edit... **********"
    Invoke-Command -ComputerName QA1-12 -ScriptBlock { stop-service w3svc } -Credential $credential

    $content = Get-Content -Path $configPath\Synergis.WebAPI\connections.config
    $newContent = $content -replace ";initial catalog=(.*);persist", ";initial catalog=$database;persist"
    Set-Content -Path $configPath\Synergis.WebAPI\connections.config -value $newContent

    Write-Host "********** Config set to $database database connection.  Restarting IIS... **********"
    Invoke-Command -ComputerName QA1-12 -ScriptBlock { Start-Service w3svc } -Credential $credential
    
    # Run the tests
    #testcafe chrome tests/qa/$folder/*.ts -r xunit:report/$database.xml
    testcafe chrome tests/qa/$folder/check-out-dialog.ts -r xunit:report/$database.xml

    # Not sure if QA using the TestCafe reporting setup so delete the report.xml
    if (Test-Path $testCafeDir\report\report.xml) 
    {
        Remove-Item $testCafeDir\report\report.xml
    }

}

Write-Host "********** IIS Shutting to restore Quality Db access... **********"
Invoke-Command -ComputerName QA1-12 -ScriptBlock { stop-service w3svc } -Credential $credential

# Reset the test server config file to the Quality Db...
$content = Get-Content -Path $configPath\Synergis.WebAPI\connections.config -Raw
$newContent = $content -replace ";initial catalog=(.*);persist", ";initial catalog=Quality;persist"
Set-Content -Path $configPath\Synergis.WebAPI\connections.config -value $newContent

Write-Host "********** Config reset to Quality database connection.  Restarting IIS... **********"
Invoke-Command -ComputerName QA1-12 -ScriptBlock { Start-Service w3svc } -Credential $credential
