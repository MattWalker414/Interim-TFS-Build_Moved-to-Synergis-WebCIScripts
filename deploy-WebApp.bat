@echo off
@rem The Synergis.WebClient folder may revert to Synergis.WebApp once Angular 6 replaces previous fully.
@set source=%1\AdeptWebClient
@set target=\\WIN2K2019-MATT\BuildDump\Synergis.WebApp

@rem echo -----> Remove existing --- commented as previous deployment cleared from post build script
@rem del /q /s %target%\*.*
@rem rd /s /q %target%\app
@rem rd /s /q %target%
@rem md %target%

@rem Restored the cleanup of previous deployment since moving the WebAPP copy call from script to task.
@rem Delete everything in Synergis.WebApp folder...
del /q %target%\*
FOR /D %%p IN (%target%\*.*) DO rmdir "%%p" /s /q

@rem echo -----> Copy directories and files within
@rem Contents of Synergis.WebClient's (or .WebApp) dist folder to be copied to fs2 Synergis.WebApp (not containing dist parent folder)
echo f | xcopy /e /y %source%\dist\webclient\*.* %target%

goto end
@rem Copy DynamicModel Compile .exe
@set target=\\fs2\installs\nAWC12.0.0\0_Development\Synergis.WebApi\bin

@set source=%1\Development\12.0\Web\AdeptWeb\Synergis.DynamicModelConsole\bin\Release
echo f | xcopy /y %source%\Synergis.DynamicModelConsole.exe %target%\
echo f | xcopy /y %source%\Synergis.DynamicModelConsole.exe.config %target%\

@rem - Get the correct Synergis.DomainModel.dll in place as there were issues building Dynamic Model .dll on Test Server...
@set source=%1\Development\12.0\Web\AdeptWeb\Synergis.WebAPI\bin
echo f | xcopy /y %source%\Synergis.DomainModel.dll %target%\

end:
