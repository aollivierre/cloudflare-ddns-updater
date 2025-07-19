' KeepAwakeInvisible.vbs
' This script launches PowerShell completely hidden without showing any window
' Created to solve the issue of visible windows when using -WindowStyle Hidden

Option Explicit

' Define the path to PowerShell and the script
Dim PowerShellPath, ScriptPath, Arguments
PowerShellPath = "powershell.exe"
ScriptPath = "C:\code\KeepAwake\KeepAwake.ps1"
Arguments = "-NoProfile -ExecutionPolicy Bypass -File """ & ScriptPath & """"

' Create a shell object
Dim objShell
Set objShell = CreateObject("WScript.Shell")

' Run PowerShell with 0 window style (hidden)
' 0 = Hidden window
' True = don't wait for program to finish
objShell.Run PowerShellPath & " " & Arguments, 0, False

' Clean up
Set objShell = Nothing 