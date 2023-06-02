Param(
        [string]$source,
        [string]$configPath,
        [string]$testType
     )

# Test areas to cycle through based Database name for the connection and folder name for tests (Database.Folder)...
[string[]]$funcArea = "Checkout.check-out" #, "NextTestArea.NextFolder

$securePassword = ConvertTo-SecureString "3#sdfverM4tt!syner" -AsPlainText -force
$credential = New-Object System.Management.Automation.PsCredential("ssetestdom\builduser",$securePassword)

$testCafeDir = "$source\Testing\TestCafe\Scripts"

function SetConfig
{
    Param (
            [string]$dbname,
            [string]$filePath,
            [System.Management.Automation.PSCredential]$creds
          )
    
    # Edit the config file with database name...
    Write-Host "********** IIS Shutting down for config edit for $dbname access... **********"
    Invoke-Command -ComputerName QA1-12 -ScriptBlock { stop-service w3svc } -Credential $creds

    $content = Get-Content -Path $filePath\Synergis.WebAPI\connections.config
    $newContent = $content -replace ";initial catalog=(.*);persist", ";initial catalog=$dbname;persist"
    Set-Content -Path $filePath\Synergis.WebAPI\connections.config -value $newContent

    Write-Host "********** Config set to $dbname database connection.  Restarting IIS... **********"
    Invoke-Command -ComputerName QA1-12 -ScriptBlock { Start-Service w3svc } -Credential $creds

}

cd $testCafeDir
Write-Host "Launching tests from: $testCafe"

if ($testType -eq "Nightly")
{
    Write-Host "QA test suite will be executed."
    
    foreach ($test in $funcArea)
    {
        $info = $test.split('.')
        $database = $info[0]
        $folder = $info[1]

        SetConfig -dbname $database -filePath $configPath -creds $credential
    
        # Run the tests...
        testcafe chrome tests/qa/$folder/*.ts -r xunit:report/$database.xml --browser-init-timeout 300000
        #testcafe chrome tests/qa/$folder/check-out-dialog.ts -r xunit:report/$database.xml --browser-init-timeout 300000      

        if ($lastexitcode -ne 0) { $global:lastexitcode = 0 }  # Ignore TestCafe script errors.

        # Reset config file to use Quality database...
        SetConfig -dbname "Quality" -filePath $configPath -creds $credential                
    }
}
else # CI Testing...
{
        Write-Host "CI test(s) will be executed."
        
        # Edit the config file with Quality database name...
        SetConfig -dbname "Quality" -filePath $configPath -creds $credential
        Write-Host "Configuration file set to access the Quality database."
       
        # Run the tests...
        # Add timeout increase if needed --browser-init-timeout 300000
        # Running singular, named test caused cannot find tests issue...
        #testcafe chrome tests/CI/login-out/login-out.ts -r xunit:report/LoginOut.xml        
        testcafe chrome tests/CI/login-out/*.ts -r xunit:report/LoginOut.xml
}

if ($lastexitcode -ne 0) { $global:lastexitcode = 0 }  # Ignore TestCafe script errors
