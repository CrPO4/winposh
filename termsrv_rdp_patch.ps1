# PowerShell script used to patch termsrv.dll file and allow multiple RDP connections on Windows 10 (1809 and never) and Windows 11 
# Details here http://woshub.com/how-to-allow-multiple-rdp-sessions-in-windows-10/
# Stop RDP service, make a backup of the termsrv.dllfile and change the permissions

$newByteSyntax = [System.Version]$(Get-Host | Select-Object "Version" -ExpandProperty "Version") -ge [System.Version]"6.0.0"
$backupExists = Test-Path -Path c:\windows\system32\termsrv.dll.backup

Stop-Service UmRdpService -Force
Stop-Service TermService -Force
$termsrv_dll_acl = Get-Acl c:\windows\system32\termsrv.dll

if (-Not $backupExists)
{
    Copy-Item c:\windows\system32\termsrv.dll c:\windows\system32\termsrv.dll.backup
}

takeown /f c:\windows\system32\termsrv.dll
$new_termsrv_dll_owner = (Get-Acl c:\windows\system32\termsrv.dll).owner
cmd /c "icacls c:\windows\system32\termsrv.dll /Grant ""$($new_termsrv_dll_owner):F"" /C"
# search for a pattern in termsrv.dll file 
$dll_as_bytes = ''
if ($newByteSyntax) 
{ 
	$dll_as_bytes = Get-Content c:\windows\system32\termsrv.dll -Raw -AsByteStream
} else 
{ 
	$dll_as_bytes = Get-Content c:\windows\system32\termsrv.dll -Raw -Encoding Byte
}
$dll_as_text = $dll_as_bytes.forEach('ToString', 'X2') -join ' '
$patternregex = ([regex]'39 81 3C 06 00 00(\s\S\S){6}')
$patch = 'B8 00 01 00 00 89 81 38 06 00 00 90'
$checkPattern=Select-String -Pattern $patternregex -InputObject $dll_as_text
If ($checkPattern -ne $null) {
    $dll_as_text_replaced = $dll_as_text -replace $patternregex, $patch
}
Elseif (Select-String -Pattern $patch -InputObject $dll_as_text) {
    Write-Output 'The termsrv.dll file is already patched, exiting'
    Start-Service UmRdpService
    Start-Service TermService
    Exit
}
else { 
    Write-Output "Pattern not found "
}
# patching termsrv.dll
[byte[]] $dll_as_bytes_replaced = -split $dll_as_text_replaced -replace '^', '0x'
if ($newByteSyntax) 
{ 
	Set-Content c:\windows\system32\termsrv.dll.patched -AsByteStream -Value $dll_as_bytes_replaced
} else 
{ 
	Set-Content c:\windows\system32\termsrv.dll.patched -Encoding Byte -Value $dll_as_bytes_replaced
}
# comparing two files 
fc.exe /b c:\windows\system32\termsrv.dll.patched c:\windows\system32\termsrv.dll
# replacing the original termsrv.dll file 
Copy-Item c:\windows\system32\termsrv.dll.patched c:\windows\system32\termsrv.dll -Force
Remove-Item c:\windows\system32\termsrv.dll.patched -Force
Set-Acl c:\windows\system32\termsrv.dll $termsrv_dll_acl
Start-Service UmRdpService
Start-Service TermService
