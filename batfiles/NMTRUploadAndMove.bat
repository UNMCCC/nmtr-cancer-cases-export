@echo off
"C:\Program Files (x86)\WinSCP\WinSCP.com" /log="\\\MQAPPLYRSRVR\MOSAIQ_App\EXPORT\NMTR\Log\WinSCPUpload.log" /script="C:\NMTRScripts\uploadNMTRscript.txt"
 
if %ERRORLEVEL% neq 0 goto error
 
echo Upload succeeded, moving local files
move \\MQAPPLYRSRVR\MOSAIQ_App\EXPORT\NMTR\Upload\*.* \\MQAPPLYRSRVR\MOSAIQ_App\EXPORT\NMTR\UploadComplete
exit 0
 
:error
echo Upload failed, keeping local files
exit 1