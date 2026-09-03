# Registers the three daily builder slots (10:00 / 15:00 / 21:00, never Embermarch's 09/14/20)
# and a Sunday export. Run once, by hand:  pwsh tools\install-schedule.ps1   (add -Remove to undo)
param([switch]$Remove)
$repo = Split-Path -Parent $PSScriptRoot
$pwsh = (Get-Command pwsh).Source
$names = @{ "Briarhold build AM" = "10:00"; "Briarhold build MID" = "15:00"; "Briarhold build PM" = "21:00" }
foreach ($n in $names.Keys) {
  Unregister-ScheduledTask -TaskName $n -Confirm:$false -ErrorAction SilentlyContinue
  if ($Remove) { continue }
  $action = New-ScheduledTaskAction -Execute $pwsh -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$repo\build.ps1`"" -WorkingDirectory $repo
  $trigger = New-ScheduledTaskTrigger -Daily -At $names[$n]
  $settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Hours 2) -StartWhenAvailable -MultipleInstances IgnoreNew
  # Interactive token: the screenshot gate needs the user's desktop session (no stored password)
  $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited
  Register-ScheduledTask -TaskName $n -Action $action -Trigger $trigger -Settings $settings -Principal $principal | Out-Null
  Write-Host "registered $n at $($names[$n])"
}
$exportName = "Briarhold export SUN"
Unregister-ScheduledTask -TaskName $exportName -Confirm:$false -ErrorAction SilentlyContinue
if (-not $Remove) {
  $action = New-ScheduledTaskAction -Execute $pwsh -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$repo\build.ps1`" -Export" -WorkingDirectory $repo
  $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At "12:00"
  $settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Hours 2) -StartWhenAvailable -MultipleInstances IgnoreNew
  $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited
  Register-ScheduledTask -TaskName $exportName -Action $action -Trigger $trigger -Settings $settings -Principal $principal | Out-Null
  Write-Host "registered $exportName Sunday 12:00"
}
Get-ScheduledTask | Where-Object TaskName -like "Briarhold*" | Select-Object TaskName, State | Format-Table -AutoSize
