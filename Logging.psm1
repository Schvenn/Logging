$script:powershell = Split-Path $profile; $global:TranscriptRunning = $false

# (Internal) Function to clean log file after it has been written.
function cleanlogfiles {# Recurse through log directory
$logDirectory = "$powershell\Transcripts"; $logFiles = Get-ChildItem -Path $logDirectory -Filter *.log; $threshold = (Get-Date).AddDays(-30)

# Delete old log files.
Get-ChildItem -Path $logDirectory -Filter *.log | ForEach-Object {if ($_ -match '\d{2}-\d{2}-\d{4}') {$dateString = $matches[0]
$logDate = [datetime]::ParseExact($dateString, 'MM-dd-yyyy', $null)
if ($logDate.Date -lt $threshold) {if (Get-Command Remove-ToRecycleBin -ErrorAction SilentlyContinue) {Remove-ToRecycleBin $_.FullName}
else {Remove-Item $_.FullName -Force}}}}
# Reacquire list of log files, in case it changed.
$logFiles = Get-ChildItem -Path $logDirectory -Filter *.log

# Obtain remaining log files.
foreach ($logfile in $logFiles) {$secondLine = (Get-Content $logfile -TotalCount 2)[1]
if ($secondLine -eq "PowerShell transcript start") {Write-Host -f cyan "`nRunning cleanup on $logfile`n"; 

# Load file content.
$fileContent = Get-Content "$logfile" -ErrorAction SilentlyContinue; $skipTargets = @(); $cleanedContent = @()

# Remove header.
$start = 0; $end = 0; $foundFirst = $false
for ($i = 0; $i -lt $fileContent.Count; $i++) {if ($fileContent[$i] -match '^\*{20,}$') {if (-not $foundFirst) {$foundFirst = $true; $start = $i}
else {$end = $i; break}}}
if ($end -gt $start) {$fileContent = $fileContent[($end + 1)..($fileContent.Count - 1)]}

# Remove footer.
$footerStart = -1; $footerEnd = -1
for ($i = $fileContent.Count - 1; $i -ge 0; $i--) {if ($fileContent[$i] -match '^\*{20,}$') {if ($footerEnd -eq -1) {$footerEnd = $i}
elseif ($fileContent[$i + 1] -like '*PowerShell transcript end*') {$footerStart = $i; break}}}
if ($footerStart -ge 0 -and $footerEnd -gt $footerStart) {$fileContent = $fileContent[0..($footerStart - 1)]}

# Clean Error Logs heading.
for ($i = 0; $i -lt $fileContent.Count; $i++) {$line = $fileContent[$i]
if ($line -match '^ERROR LOGS:$' -and $i + 3 -lt $fileContent.Count) {$skipTargets += ($i + 2); $skipTargets += ($i + 3)}}

# Remove ~ lines.
for ($i = 0; $i -lt $fileContent.Count; $i++) {$line = $fileContent[$i]; if ($line.Trim() -match '^~+$') {continue}
if ($skipTargets -contains $i) {continue}

# Separate prompt lines.
if ($line -match '(?i)^(PS>|(\w:\\)[^>]+>).*$') {$cleanedContent += '-' * 100}

# Write cleaned transcript file.
$cleanedContent += $line}
$cleanedContent | Set-Content "$logfile"}}}

function lasterrors ($numberoferrors = 5) {# Recall the last number of error messages that PowerShell generated, excluding typos.
$numberoferrors = [int]$numberoferrors; if ($global:Error.Count -gt 0) {""; Write-Host ("-"*100) -f yellow}; $global:Error | Where-Object {$_.ToString() -notmatch 'is not recognized as a name of a cmdlet'} | Select-Object -First $numberoferrors | ForEach-Object {$e = $_; if ($e.Exception.Message) {Write-Host "$($e.Exception.Message)" -f red
if ($e.InvocationInfo -and $e.InvocationInfo.PositionMessage) {$position = $e.InvocationInfo.PositionMessage -replace '(\+\s+|~{5,}.+$|`n)', ''}
Write-Host "$($position.trim())" -f white; Write-Host ("-"*100) -f yellow}}; ""}

function log ($mode){# Toggle PowerShell logging.
$logdirectory = Join-Path $powershell transcripts; $logfile = "$logdirectory\Powershell log - $(Get-Date -Format 'MM-dd-yyyy_HH꞉mm').log"

# Start and Stop Logging functions.
function startlogging {""; cleanlogfiles; Start-Transcript "$logfile" | Write-Host -f green; $global:TranscriptRunning = $true; ""; return}
function stoplogging {""; Write-Host ("="*100); Write-Host "ERROR LOGS:"; Write-Host ("="*100); lasterrors 100; $error.clear(); Stop-Transcript | Write-Host -f darkgray; $global:TranscriptRunning = $false; cleanlogfiles; return}

# Mode Start/Stop/Status.
if ($mode -match "(?i)^start$") {if ($global:TranscriptRunning -eq $false) {startlogging; return} else {Write-Host -f cyan "`nLogging is already running.`n"; return}}
elseif ($mode -match "(?i)^stop$") {if ($global:TranscriptRunning -eq $true) {stoplogging; return} else {Write-Host -f cyan "`nLogging is not currently running.`n"; return}}
elseif ($mode -match "(?i)^status$") {$status = if ($global:TranscriptRunning -eq $true) {"running"} else {"stopped"} Write-Host -f cyan "`nPowerShell logging is currently $status.`n"; return}

# Error-checking.
if ($mode -and $mode -notmatch "(?i)^st(art|op|atus)$") {Write-Host -f cyan "`nUsage: log <start/stop/status>`n"; return}

# No mode specified.
elseif ($global:TranscriptRunning = $true) {stoplogging; return}
else {startlogging; return}}

Export-ModuleMember -Function lasterrors, log, remove-torecyclebin

<#
## Overview

PowerShell's Start and Stop Transcript commands are great for logging, but the resulting files are difficult to read and they lack a centralized error tracking mechanism. So, this tool was created to alleviate some of those difficulties.

	• The log function allows you to start and stop transcript logging, or check on the status, if you're unsure of it's current state.
	• When logging is stopped, the module will append the last 100 errors before closing the transcript.
	• Logs will then be cleaned by removing any that are over 30 days old, stripping away the default headers and footers, adding visual separators between command line interactions and leaving only the most important parts of the errors in each of the remaining files.
## lasterrors 

This function recalls the last set of error messages that PowerShell generated, excluding command-not-found errors, formatted on screen for easier reading.
Optionally specify a # of errors to view. The default is 5.
This function is used at the end of the command to stop logging, in order to ensure that centralized error tracking is included.

	Usage: lasterrors #
## log

Turn transaction logging in PowerShell on or off, or check on its status.

	Usage: log <start/stop/status>
##>
