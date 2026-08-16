Option Explicit

Dim shellApp, fso, folder, scriptPath, args
Set shellApp = CreateObject("Shell.Application")
Set fso = CreateObject("Scripting.FileSystemObject")

folder = fso.GetParentFolderName(WScript.ScriptFullName)
scriptPath = fso.BuildPath(folder, "StreamDeckAutoRecover.ps1")

args = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & scriptPath & """"

' "runas" requests Administrator privileges.
' Final 0 asks Windows to keep the PowerShell host hidden.
shellApp.ShellExecute "powershell.exe", args, folder, "runas", 0
