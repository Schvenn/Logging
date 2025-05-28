$script:powershell = Split-Path $profile; $global:TranscriptRunning = $false

# Editor.
function edit ($file) {$script:edit = "notepad"; $npp = "Notepad++\notepad++.exe"; $paths = @("$env:ProgramFiles", "$env:ProgramFiles(x86)")
foreach ($path in $paths) {$test = Join-Path $path $npp; if (Test-Path $test) {$script:edit = $test; break}}
& $script:edit $file}

# Format log files.
function trimlogfile ($logfile) {$secondLine = (Get-Content $logfile -TotalCount 2)[1]
if ($secondLine -match "(Windows )?PowerShell transcript start$") {Write-Host -f cyan "Running cleanup on $logfile"

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
$cleanedContent | Set-Content "$logfile"}}

# (Internal) Function to clean log file after it has been written.
function cleanlogfiles {# Recurse through log directory
$logDirectory = "$powershell\Transcripts"; $logFiles = Get-ChildItem -Path $logDirectory -Filter *.log; $threshold = (Get-Date).AddDays(-30)

# Delete old log files.
Get-ChildItem -Path $logDirectory -Filter *.log | ForEach-Object {if ($_ -match '\d{2}-\d{2}-\d{4}') {$dateString = $matches[0]
$logDate = [datetime]::ParseExact($dateString, 'MM-dd-yyyy', $null)
if ($logDate.Date -lt $threshold) {if (Get-Command Recycle -ErrorAction SilentlyContinue) {Recycle $_.FullName}
else {Remove-Item $_.FullName -Force}}}}
# Reacquire list of log files, in case it changed.
$logFiles = Get-ChildItem -Path $logDirectory -Filter *.log

# Obtain remaining log files.
foreach ($logfile in $logFiles) {trimlogfile $logfile}}

function lasterrors ($numberoferrors = 5) {# Recall the last number of error messages that PowerShell generated, excluding typos.
$numberoferrors = [int]$numberoferrors; if ($global:Error.Count -gt 0) {""; Write-Host ("-"*100) -f yellow}; $global:Error | Where-Object {$_.ToString() -notmatch 'is not recognized as a name of a cmdlet'} | Select-Object -First $numberoferrors | ForEach-Object {$e = $_; if ($e.Exception.Message) {Write-Host "$($e.Exception.Message)" -f red
if ($e.InvocationInfo -and $e.InvocationInfo.PositionMessage) {$position = $e.InvocationInfo.PositionMessage -replace '(\+\s+|~{5,}.+$|`n)', ''}
Write-Host "$($position.trim())" -f white; Write-Host ("-"*100) -f yellow}}; ""}

function log ($mode, [switch]$help){# Toggle PowerShell logging.
$logdirectory = Join-Path $powershell transcripts; $logfile = "$logdirectory\Powershell log - $(Get-Date -Format 'MM-dd-yyyy_HH꞉mm').log"

if ($help) {function scripthelp ($section) {# (Internal) Generate the help sections from the comments section of the script.
""; Write-Host -f yellow ("-" * 100); $pattern = "(?ims)^## ($section.*?)(##|\z)"; $match = [regex]::Match($scripthelp, $pattern); $lines = $match.Groups[1].Value.TrimEnd() -split "`r?`n", 2; Write-Host $lines[0] -f yellow; Write-Host -f yellow ("-" * 100)
if ($lines.Count -gt 1) {$lines[1] | Out-String | Out-Host -Paging}; Write-Host -f yellow ("-" * 100)}
$scripthelp = Get-Content -Raw -Path $PSCommandPath; $sections = [regex]::Matches($scripthelp, "(?im)^## (.+?)(?=\r?\n)")
if ($sections.Count -eq 1) {cls; Write-Host "$([System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath)) Help:" -f cyan; scripthelp $sections[0].Groups[1].Value; ""; return}
$selection = $null
do {cls; Write-Host "$([System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath)) Help Sections:`n" -f cyan; for ($i = 0; $i -lt $sections.Count; $i++) {
"{0}: {1}" -f ($i + 1), $sections[$i].Groups[1].Value}
if ($selection) {scripthelp $sections[$selection - 1].Groups[1].Value}
$input = Read-Host "`nEnter a section number to view"
if ($input -match '^\d+$') {$index = [int]$input
if ($index -ge 1 -and $index -le $sections.Count) {$selection = $index}
else {$selection = $null}} else {""; return}}
while ($true); return}

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

function logviewer ($log, [switch]$help) {# Transations Log Viewer.
""

if ($help) {function scripthelp ($section) {# (Internal) Generate the help sections from the comments section of the script.
Write-Host -f yellow ("-" * 100); $pattern = "(?ims)^## ($section.*?)(##|\z)"; $match = [regex]::Match($scripthelp, $pattern); $lines = $match.Groups[1].Value.TrimEnd() -split "`r?`n", 2; Write-Host $lines[0] -f yellow; Write-Host -f yellow ("-" * 100)
if ($lines.Count -gt 1) {$lines[1] | Out-String | Out-Host -Paging}; Write-Host -f yellow ("-" * 100)}
$scripthelp = Get-Content -Raw -Path $PSCommandPath; $sections = [regex]::Matches($scripthelp, "(?im)^## (.+?)(?=\r?\n)")
if ($sections.Count -eq 1) {cls; Write-Host "$([System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath)) Help:" -f cyan; scripthelp $sections[0].Groups[1].Value; ""; return}
$selection = $null
do {cls; Write-Host "$([System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath)) Help Sections:`n" -f cyan; for ($i = 0; $i -lt $sections.Count; $i++) {
"{0}: {1}" -f ($i + 1), $sections[$i].Groups[1].Value}
if ($selection) {scripthelp $sections[$selection - 1].Groups[1].Value}
$input = Read-Host "`nEnter a section number to view"
if ($input -match '^\d+$') {$index = [int]$input
if ($index -ge 1 -and $index -le $sections.Count) {$selection = $index}
else {$selection = $null}} else {""; return}}
while ($true); return}

# Menu Presentation.
$transcriptPath = "$powershell\transcripts"

:mainmenu while ($true) {if (-not $log) {$logs = Get-ChildItem "$transcriptPath\*.log" | Where-Object {$_.Name -match '^Powershell log - \d{2}-\d{2}-\d{4}'}
if (-not $logs) {Write-Host -f red "`nNo .log files found in the Transcripts directory.`n"; return}

# Extract date from filenames.
$logsWithDates = foreach ($logFile in $logs) {if ($logFile.Name -match '^Powershell log - (\d{2})-(\d{2})-(\d{4})') {$date = "$($matches[3])-$($matches[1])-$($matches[2])"
$logFile | Add-Member -NotePropertyName LogDate -NotePropertyValue $date -PassThru}}
if (-not $logsWithDates) {Write-Host -f red "`nNo logs matched filename date format.`n"; return}

$grouped = $logsWithDates | Group-Object LogDate | Sort-Object Name -Descending
$selectedLogs = $null

# Date range selector.
while ($true) {cls; Write-Host -f white "Select a date:"; Write-Host -f cyan ("-" * 45)
for ($i = 0; $i -lt $grouped.Count; $i++) {$date = $grouped[$i].Name; $count = $grouped[$i].Group.Count; Write-Host "$($i+1):" -f cyan -n; Write-Host " $date ($count logs)" -f white}
Write-Host -f white "`nSelect a date range or Q to quit" -n; $input = Read-Host " "
if ($input -match '^[Qq]$') {""; return}
if ($input -match '^\d+$') {[int]$dateChoice = $input
if ($dateChoice -ge 1 -and $dateChoice -le $grouped.Count) {$selectedLogs = $grouped[$dateChoice - 1].Group; break}}}

# File selector.
while ($true) {cls; Write-Host -f white "Select a file:"; Write-Host -f cyan ("-" * 45); Write-Host -f cyan "«" -n; Write-Host -f white "    .."
for ($i = 0; $i -lt $selectedLogs.Count; $i++) {Write-Host -f cyan "$($i+1):" -n; Write-Host -f white " $($selectedLogs[$i].Name)" -n; $sizeKB = try {[math]::Round(((Get-Item $selectedLogs[$i]).Length + 500) / 1KB, 0)} catch {" "}; Write-Host -f white " [$sizeKB KB]"}
Write-Host -f white "`nSelect a log to view or Q to quit" -n; $input = Read-Host " "
if ($input -match '^[Qq]$') {return}
if ($input -match '(^0$|^$)') {return logviewer}
if ($input -match '^\d+$') {[int]$choice = $input
if ($choice -ge 1 -and $choice -le $selectedLogs.Count) {$log = $selectedLogs[$choice - 1].FullName; break}}}}break}

# Error-checking
if (-not (Test-Path $log)) {Write-Host -f red "`nLog file not found.`n"; return}

# Read log content once
$content = Get-Content $log
if (-not $content) {Write-Host -f red "`nFile is empty.`n"; return}

$separators = @(0) + (0..($content.Count - 1) | Where-Object {$content[$_] -match '^[=]{100}$'}); $pageSize = 35; $pos = 0; $logName = [System.IO.Path]::GetFileName($log); $searchHits = @(); $currentSearchIndex = -1

function Get-BreakPoint {param($start); $maxEnd = [Math]::Min($start + $pageSize - 1, $content.Count - 1); for ($i = $start + 29; $i -le $maxEnd; $i++) {if ($content[$i] -match '^[-=]{100}$') {return $i}}; return $maxEnd}

function Show-Page {cls; $start = $pos; $end = Get-BreakPoint $start; $pageLines = $content[$start..$end]; $highlight = if ($searchTerm) {"(?i)" + [regex]::Escape($searchTerm)} else {$null}
foreach ($line in $pageLines) {if ($line -match '^[-=]{100}$') {Write-Host -ForegroundColor Yellow $line}
elseif ($highlight -and $line -match $highlight) {$parts = [regex]::Split($line, "($highlight)")
foreach ($part in $parts) {if ($part -match "^$highlight$") {Write-Host -f black -b yellow $part -n}
else {Write-Host -f white $part -n}}; ""}
else {Write-Host -f white $line}}
# Pad with blank lines if this page has fewer than $pageSize lines
$linesShown = $end - $start + 1
if ($linesShown -lt $pageSize) {for ($i = 1; $i -le ($pageSize - $linesShown); $i++) {Write-Host ""}}}

$errormessage = ""; $searchmessage = "Search Commands"
# Main menu loop
while ($true) {Show-Page; $pageNum = [math]::Floor($pos / $pageSize) + 1; $totalPages = [math]::Ceiling($content.Count / $pageSize)
if ($searchHits.Count -gt 0) {$currentMatch = ($searchHits | Where-Object {$_ -eq $pos} | ForEach-Object {[array]::IndexOf($searchHits, $_) + 1})
if ($currentMatch) {$searchmessage = "Match $currentMatch of $($searchHits.Count)"}}
""; Write-Host -f yellow ("=" * 130)
$left = "$logName".PadRight(57); $middle = "$errormessage".PadRight(54); $right = "(Page $pageNum of $totalPages)"
Write-Host -f white $left -n; Write-Host -f red $middle -n; Write-Host -f cyan $right
$left = "Page Commands".PadRight(55); $middle = "| $searchmessage ".PadRight(44); $right = "| Exit Commands"
Write-Host -f yellow ($left + $middle + $right)
Write-Host -f yellow "[F]irst [N]ext [+/-]# Lines p[A]ge # [P]revious [L]ast | [<][S]earch[>] [#]Number [C]lear [E]rrors | [D]ump [X]Edit [M]enu [Q]uit" -n; $action = Read-Host " "
$errormessage = ""; $searchmessage = "Search Commands"

if ($action -match '^[+-]?\d+$') {$offset = [int]$action; $newPos = $pos + $offset; $pos = [Math]::Max(0, [Math]::Min($newPos, $content.Count - $pageSize))}

if ($action -match '^#([+-]?\d+)$') {$jump = [int]$matches[1]
if (-not $searchHits -or $searchHits.Count -eq 0) {$errormessage = "No search in progress."}
else {if ($jump -ge 1 -or $jump -le -1) {$targetIndex = if ($jump -lt 0) {[Math]::Max(0, $currentSearchIndex + $jump)} 
else {$jump - 1}
if ($targetIndex -ge 0 -and $targetIndex -lt $searchHits.Count) {$pos = $searchHits[$targetIndex]; $errormessage = "Jumped to match #$($targetIndex + 1)."} 
else {$errormessage = "Match #$jump is out of range."}} 
else {$pos = $searchHits[0]; $errormessage = "Jumped to first match."}}}

if ($action -match '^A(\d+)$') {$requestedPage = [int]$matches[1]
if ($requestedPage -lt 1 -or $requestedPage -gt $totalPages) {$errormessage = "Page #$requestedPage is out of range."}
else {$pos = ($requestedPage - 1) * $pageSize}}

switch ($action.ToUpper()) {'F' {$pos = 0}
'<' {$currentSearchIndex = ($searchHits | Where-Object {$_ -lt $pos} | Select-Object -Last 1)
if ($null -eq $currentSearchIndex -and $searchHits -ne @()) {$currentSearchIndex = $searchHits[-1]; $errormessage = "Wrapped to last match."}
$pos = $currentSearchIndex}
'S' {Write-Host -f green "Keyword to search forward from this point in the logs" -n; $searchTerm = Read-Host " "
if (-not $searchTerm) {$errormessage = "No keyword entered."; $searchTerm = $null; $searchHits = @(); break}
$pattern = "(?i)" + [regex]::Escape($searchTerm); $searchHits = @(0..($content.Count - 1) | Where-Object {$content[$_] -match $pattern})
if (-not $searchHits) {$errormessage = "Keyword not found in file."; $searchHits = @(); $currentSearchIndex = -1}
$currentSearchIndex = $searchHits | Where-Object {$_ -gt $pos} | Select-Object -First 1
if ($null -eq $currentSearchIndex) {Write-Host -f green "No match found after this point. Jump to first match? (Y/N)" -n; $wrap = Read-Host " "
if ($wrap -match '^[Yy]$') {$currentSearchIndex = $searchHits[0]}
else {$errormessage = "Keyword not found further forward."; $searchHits = @()}}
$pos = $currentSearchIndex}
'>' {$currentSearchIndex = ($searchHits | Where-Object {$_ -gt $pos} | Select-Object -First 1)
if ($null -eq $currentSearchIndex -and $searchHits -ne @()) {$currentSearchIndex = $searchHits[0]; $errormessage = "Wrapped to first match."}
$pos = $currentSearchIndex}
'N' {$next = Get-BreakPoint $pos; if ($next -lt $content.Count - 1) {$pos = $next + 1} else {$pos = [Math]::Min($pos + $pageSize, $content.Count - 1)}}
'P' {$pos = [Math]::Max(0, $pos - $pageSize)}
'L' {$lastPageStart = [Math]::Max(0, [int][Math]::Floor(($content.Count - 1) / $pageSize) * $pageSize); $pos = $lastPageStart}
'C' {$searchTerm = $null; $searchHits.Count = 0; $searchHits = @(); $currentSearchIndex = $null}
'D' {""; gc $log | more; return}
'X' {edit $log; "" ; return}
'M' {return logviewer}
'Q' {""; return}
'E' {$errIndex = $content.IndexOf("ERROR LOGS:")
if ($errIndex -ge 0) {$nextDelim = $separators | Where-Object {$_ -gt $errIndex}
if ($nextDelim) {$pos = $nextDelim[0]}}
else {$errormessage = "'ERROR LOGS:' section not found."}}
default {Write-Host -f red "`nInvalid input.`n"}}}}

Export-ModuleMember -Function lasterrors, log, logviewer

<#
## Overview

PowerShell's Start and Stop Transcript commands are great for logging, but the resulting files are difficult to read and they lack a centralized error tracking mechanism. So, this tool was created to alleviate some of those difficulties.

	• The log function allows you to start and stop transcript logging, or check on the status, if you're unsure of it's current state.
	• When logging is stopped, the module will append the last 100 errors before closing the transcript.
	• Logs will then be cleaned by removing any that are over 30 days old, stripping away the default headers and footers, adding visual separators and trimming error text.
	• A supplemental log viewer is also provided which features a file selection menu, internal file navigation and search capabilities.
## lasterrors 

This function recalls the last set of error messages that PowerShell generated, excluding command-not-found errors, formatted on screen for easier reading.
Optionally specify a # of errors to view. The default is 5.
This function is used at the end of the command to stop logging, in order to ensure that centralized error tracking is included.

Usage: lasterrors #
## log

Turn transaction logging in PowerShell on or off, or check on its status.

Usage: log <start/stop/status> -help
## Logviewer
This logviewer will find all properly formatted .log files in the Transcripts directory and present them on screen for easy viewing.
If no file is provided, a menu of Transcripts organized by date will be presented for selection.

	Usage: logviewer <filename> -help

Once inside the viewer, the options include:

Navigation:

	[F]irst page
	[N]ext page
	[+/-]# to move forward or back a specific # of lines
	p[A]ge # to jump to a specific page
	[P]revious page
	[L]ast page

Search:

	[S]earch for a term
	[<] Previous match
	[>] Next match
	[#]Number to find a specific match number
	[C]lear search term
	[E]rrors to jump to the ERROR LOGS section, if available

Exit Commands:

	[D]ump to screen with | MORE and Exit
	[X]Edit using Notepad++, if available. Otherwise, use Notepad.
	[M]enu to open the file selection menu
	[Q]uit
##>
