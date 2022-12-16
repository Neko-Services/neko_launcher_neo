param(
    [Parameter(Mandatory=$True)][string]$version
)

Write-Output "Ensuring the right icon..."
Copy-Item ".\assets\neko.ico" ".\windows\runner\resources\app_icon.ico"
if ($?) {
    Write-Output "Building Neko Launcher Neo!"
    flutter.bat build windows --build-name $version
    if ($LASTEXITCODE -eq 0) {
        Write-Output "Copying necessary DLL files..."
        try {
            Copy-Item "C:\Windows\System32\msvcp140.dll" ".\build\windows\runner\Release\"
            Copy-Item "C:\Windows\System32\vcruntime140.dll" ".\build\windows\runner\Release\"
            Copy-Item "C:\Windows\System32\vcruntime140_1.dll" ".\build\windows\runner\Release\"
        } catch {
            Write-Error "Couldn't copy DLL files from System32."
            return
        }
        Write-Output "Deleting old archive(s)..."
        Remove-Item ".\archives\*" -Filter "*-$version-windows.zip"
        if ($?) {
            Write-Output "Packaging new archive..."
            7z.exe a ".\archives\neko_launcher_neo-$version-windows.zip" ".\build\windows\runner\Release\*"
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Building and packaging Neko Launcher Neo (v$version) complete!" -ForegroundColor Green
            } else {
                Write-Error "Couldn't create archive."
            }
        } else {
            Write-Error "Couldn't delete old archive(s)."
        }
    } else {
        Write-Error "There was an error building Neko Launcher Neo. Aborting."
    }
} else {
    Write-Output "Couldn't copy app icon."
}
