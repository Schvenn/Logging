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
foreach ($logfile in $logFiles) {trimlogfile $logfile}

# Compress log files over 1KB and older than 1 hour
Get-ChildItem -Path $logDirectory -Filter *.log -Recurse | Where-Object {$_.LastWriteTime -lt (Get-Date).AddHours(-1)} | ForEach-Object {$gzipPath = "$($_.FullName).gz"
try {$sourceStream = $_.OpenRead(); $targetStream = [System.IO.File]::Create($gzipPath); $gzipStream = New-Object System.IO.Compression.GZipStream($targetStream, [System.IO.Compression.CompressionMode]::Compress); $sourceStream.CopyTo($gzipStream); $gzipStream.Close(); $targetStream.Close(); $sourceStream.Close(); Remove-Item $_.FullName -Force}
catch {Write-Warning "Failed to compress $($_.FullName): $_"}}}

function lasterrors ($numberoferrors = 5) {# Recall the last number of error messages that PowerShell generated, excluding typos.
$numberoferrors = [int]$numberoferrors; if ($global:Error.Count -gt 0) {""; Write-Host ("-"*100) -f yellow}; $global:Error | Where-Object {$_.ToString() -notmatch 'is not recognized as a name of a cmdlet'} | Select-Object -First $numberoferrors | ForEach-Object {$e = $_; if ($e.Exception.Message) {Write-Host "$($e.Exception.Message)" -f red
if ($e.InvocationInfo -and $e.InvocationInfo.PositionMessage) {$position = $e.InvocationInfo.PositionMessage -replace '(\+\s+|~{5,}.+$|`n)', ''}
Write-Host "$($position.trim())" -f white; Write-Host ("-"*100) -f yellow}}; ""}

function log ($mode, [switch]$help){# Toggle PowerShell logging.
$logdirectory = Join-Path $powershell transcripts; $logfile = "$logdirectory\Powershell log - $(Get-Date -Format 'MM-dd-yyyy_HH꞉mm').log"

# Start and Stop Logging functions.
function startlogging {""; cleanlogfiles; Start-Transcript "$logfile" | Write-Host -f green; $global:TranscriptRunning = $true; ""; return}
function stoplogging {""; Write-Host ("="*100); Write-Host "ERROR LOGS:"; Write-Host ("="*100); lasterrors 100 *>&1 | Out-File $logfile; $error.clear(); Stop-Transcript | Write-Host -f darkgray; $global:TranscriptRunning = $false; cleanlogfiles; return}

# Mode Start/Stop/Status.
if ($mode -match "(?i)^start$") {if ($global:TranscriptRunning -eq $false) {startlogging; return} else {Write-Host -f cyan "`nLogging is already running.`n"; return}}
elseif ($mode -match "(?i)^stop$") {if ($global:TranscriptRunning -eq $true) {stoplogging; return} else {Write-Host -f cyan "`nLogging is not currently running.`n"; return}}
elseif ($mode -match "(?i)^status$") {$status = if ($global:TranscriptRunning -eq $true) {"running"} else {"stopped"} Write-Host -f cyan "`nPowerShell logging is currently $status.`n"; return}

# Error-checking.
if ($mode -and $mode -notmatch "(?i)^st(art|op|atus)$") {Write-Host -f cyan "`nUsage: log <start/stop/status>`n"; return}

# No mode specified.
elseif ($global:TranscriptRunning -eq $true) {stoplogging; return}
else {startlogging; return}}

# Modify fields sent to it with proper word wrapping.
function wordwrap ($field, $maximumlinelength) {if ($null -eq $field) {return $null}
$breakchars = ',.;?!\/ '; $wrapped = @()
if (-not $maximumlinelength) {[int]$maximumlinelength = (100, $Host.UI.RawUI.WindowSize.Width | Measure-Object -Maximum).Maximum}
if ($maximumlinelength -lt 60) {[int]$maximumlinelength = 60}
if ($maximumlinelength -gt $Host.UI.RawUI.BufferSize.Width) {[int]$maximumlinelength = $Host.UI.RawUI.BufferSize.Width}
foreach ($line in $field -split "`n", [System.StringSplitOptions]::None) {if ($line -eq "") {$wrapped += ""; continue}
$remaining = $line
while ($remaining.Length -gt $maximumlinelength) {$segment = $remaining.Substring(0, $maximumlinelength); $breakIndex = -1
foreach ($char in $breakchars.ToCharArray()) {$index = $segment.LastIndexOf($char)
if ($index -gt $breakIndex) {$breakIndex = $index}}
if ($breakIndex -lt 0) {$breakIndex = $maximumlinelength - 1}
$chunk = $segment.Substring(0, $breakIndex + 1); $wrapped += $chunk; $remaining = $remaining.Substring($breakIndex + 1)}
if ($remaining.Length -gt 0 -or $line -eq "") {$wrapped += $remaining}}
return ($wrapped -join "`n")}

# Display a horizontal line.
function line ($colour, $length, [switch]$pre, [switch]$post, [switch]$double) {if (-not $length) {[int]$length = (100, $Host.UI.RawUI.WindowSize.Width | Measure-Object -Maximum).Maximum}
if ($length) {if ($length -lt 60) {[int]$length = 60}
if ($length -gt $Host.UI.RawUI.BufferSize.Width) {[int]$length = $Host.UI.RawUI.BufferSize.Width}}
if ($pre) {Write-Host ""}
$character = if ($double) {"="} else {"-"}
Write-Host -f $colour ($character * $length)
if ($post) {Write-Host ""}}

function logviewer ($log, [switch]$help) {# Transactions Log Viewer.
""

function help {# Inline help.
# Select content.
$scripthelp = Get-Content -Raw -Path $PSCommandPath; $sections = [regex]::Matches($scripthelp, "(?im)^## (.+?)(?=\r?\n)"); $selection = $null; $lines = @(); $wrappedLines = @(); $position = 0; $pageSize = 30; $inputBuffer = ""

function scripthelp ($section) {$pattern = "(?ims)^## ($([regex]::Escape($section)).*?)(?=^##|\z)"; $match = [regex]::Match($scripthelp, $pattern); $lines = $match.Groups[1].Value.TrimEnd() -split "`r?`n", 2; if ($lines.Count -gt 1) {$wrappedLines = (wordwrap $lines[1] 100) -split "`n", [System.StringSplitOptions]::None}
else {$wrappedLines = @()}
$position = 0}

# Display Table of Contents.
while ($true) {cls; Write-Host -f cyan "$(Get-ChildItem (Split-Path $PSCommandPath) | Where-Object { $_.FullName -ieq $PSCommandPath } | Select-Object -ExpandProperty BaseName) Help Sections:`n"

if ($sections.Count -gt 7) {$half = [Math]::Ceiling($sections.Count / 2)
for ($i = 0; $i -lt $half; $i++) {$leftIndex = $i; $rightIndex = $i + $half; $leftNumber  = "{0,2}." -f ($leftIndex + 1); $leftLabel   = " $($sections[$leftIndex].Groups[1].Value)"; $leftOutput  = [string]::Empty

if ($rightIndex -lt $sections.Count) {$rightNumber = "{0,2}." -f ($rightIndex + 1); $rightLabel  = " $($sections[$rightIndex].Groups[1].Value)"; Write-Host -f cyan $leftNumber -n; Write-Host -f white $leftLabel -n; $pad = 40 - ($leftNumber.Length + $leftLabel.Length)
if ($pad -gt 0) {Write-Host (" " * $pad) -n}; Write-Host -f cyan $rightNumber -n; Write-Host -f white $rightLabel}
else {Write-Host -f cyan $leftNumber -n; Write-Host -f white $leftLabel}}}

else {for ($i = 0; $i -lt $sections.Count; $i++) {Write-Host -f cyan ("{0,2}. " -f ($i + 1)) -n; Write-Host -f white "$($sections[$i].Groups[1].Value)"}}

# Display Header.
line yellow 100
if ($lines.Count -gt 0) {Write-Host  -f yellow $lines[0]}
else {Write-Host "Choose a section to view." -f darkgray}
line yellow 100

# Display content.
$end = [Math]::Min($position + $pageSize, $wrappedLines.Count)
for ($i = $position; $i -lt $end; $i++) {Write-Host -f white $wrappedLines[$i]}

# Pad display section with blank lines.
for ($j = 0; $j -lt ($pageSize - ($end - $position)); $j++) {Write-Host ""}

# Display menu options.
line yellow 100; Write-Host -f white "[↑/↓]  [PgUp/PgDn]  [Home/End]  |  [#] Select section  |  [Q] Quit  " -n; if ($inputBuffer.length -gt 0) {Write-Host -f cyan "section: $inputBuffer" -n}; $key = [System.Console]::ReadKey($true)

# Define interaction.
switch ($key.Key) {'UpArrow' {if ($position -gt 0) { $position-- }; $inputBuffer = ""}
'DownArrow' {if ($position -lt ($wrappedLines.Count - $pageSize)) { $position++ }; $inputBuffer = ""}
'PageUp' {$position -= 30; if ($position -lt 0) {$position = 0}; $inputBuffer = ""}
'PageDown' {$position += 30; $maxStart = [Math]::Max(0, $wrappedLines.Count - $pageSize); if ($position -gt $maxStart) {$position = $maxStart}; $inputBuffer = ""}
'Home' {$position = 0; $inputBuffer = ""}
'End' {$maxStart = [Math]::Max(0, $wrappedLines.Count - $pageSize); $position = $maxStart; $inputBuffer = ""}

'Enter' {if ($inputBuffer -eq "") {"`n"; return}
elseif ($inputBuffer -match '^\d+$') {$index = [int]$inputBuffer
if ($index -ge 1 -and $index -le $sections.Count) {$selection = $index; $pattern = "(?ims)^## ($([regex]::Escape($sections[$selection-1].Groups[1].Value)).*?)(?=^##|\z)"; $match = [regex]::Match($scripthelp, $pattern); $block = $match.Groups[1].Value.TrimEnd(); $lines = $block -split "`r?`n", 2
if ($lines.Count -gt 1) {$wrappedLines = (wordwrap $lines[1] 100) -split "`n", [System.StringSplitOptions]::None}
else {$wrappedLines = @()}
$position = 0}}
$inputBuffer = ""}

default {$char = $key.KeyChar
if ($char -match '^[Qq]$') {"`n"; return}
elseif ($char -match '^\d$') {$inputBuffer += $char}
else {$inputBuffer = ""}}}}}

# External call to help.
if ($help) {help; return}

# Menu Presentation.
$transcriptPath = "$powershell\transcripts"

while ($true) {if (-not $log) {$logs = Get-ChildItem $transcriptPath -Include *.log, *.log.gz -Recurse | Where-Object {$_.Name -match '^Powershell log - \d{2}-\d{2}-\d{4}'}
if (-not $logs) {Write-Host -f red "`nNo .log or .log.gz files found in the Transcripts directory.`n"; return}

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
if ($log -like '*.gz') {try {$stream = [System.IO.File]::OpenRead($log); $gzip = New-Object System.IO.Compression.GZipStream($stream, [System.IO.Compression.CompressionMode]::Decompress); $reader = New-Object System.IO.StreamReader($gzip); $text = $reader.ReadToEnd(); $reader.Close(); $gzip.Close(); $stream.Close(); $content = $text -split "`r?`n"}
catch {Write-Host -f red "`nFailed to decompress .gz log file.`n"; return}}
else {$content = Get-Content $log}

if (-not $content) {Write-Host -f red "`nFile is empty.`n"; return}

$content = $content | ForEach-Object {wordwrap $_ $null} | ForEach-Object {$_ -split "`n"}

$pageSize = 44; $pos = 0; $logName = [System.IO.Path]::GetFileName($log)
$searchHits = @(0..($content.Count - 1) | Where-Object {$content[$_] -match $pattern}); $currentSearchIndex = $searchHits | Where-Object {$_ -gt $pos} | Select-Object -First 1; $pos = $currentSearchIndex

function getbreakpoint {param($start); return [Math]::Min($start + $pageSize - 1, $content.Count - 1)}

function showpage {cls; $start = $pos; $end = getbreakpoint $start; $pageLines = $content[$start..$end]; $highlight = if ($searchTerm) {"$pattern"} else {$null}
foreach ($line in $pageLines) {if ($highlight -and $line -match $highlight) {$parts = [regex]::Split($line, "($highlight)")
foreach ($part in $parts) {if ($part -match "^$highlight$") {Write-Host -f black -b yellow $part -n}
else {Write-Host -f white $part -n}}; ""}
else {Write-Host -f white $line}}

# Pad with blank lines if this page has fewer than $pageSize lines
$linesShown = $end - $start + 1
if ($linesShown -lt $pageSize) {for ($i = 1; $i -le ($pageSize - $linesShown); $i++) {Write-Host ""}}}

# Main menu loop
$statusmessage = ""; $errormessage = ""; $searchmessage = "Search Commands"
while ($true) {showpage; $pageNum = [math]::Floor($pos / $pageSize) + 1; $totalPages = [math]::Ceiling($content.Count / $pageSize)
if ($searchHits.Count -gt 0) {$currentMatch = [array]::IndexOf($searchHits, $pos); if ($currentMatch -ge 0) {$searchmessage = "Match $($currentMatch + 1) of $($searchHits.Count)"}
else {$searchmessage = "Search active ($($searchHits.Count) matches)"}}
line yellow -double
if (-not $errormessage -or $errormessage.length -lt 1) {$middlecolour = "white"; $middle = $statusmessage} else {$middlecolour = "red"; $middle = $errormessage}
$left = "$script:fileName".PadRight(57); $middle = "$middle".PadRight(54); $right = "(Page $pageNum of $totalPages)"
Write-Host -f white $left -n; Write-Host -f $middlecolour $middle -n; Write-Host -f cyan $right
$left = "Page Commands".PadRight(55); $middle = "| $searchmessage ".PadRight(43); $right = "| Exit Commands"
Write-Host -f yellow ($left + $middle + $right)
Write-Host -f yellow "[F]irst [N]ext [+/-]# Lines p[A]ge # [P]revious [L]ast | [<][S]earch[>] [#]Match [C]lear [E]rrors | [D]ump [X]Edit [M]enu [Q]uit " -n
$statusmessage = ""; $errormessage = ""; $searchmessage = "Search Commands"

function getaction {[string]$buffer = ""
while ($true) {$key = [System.Console]::ReadKey($true)
switch ($key.Key) {'LeftArrow' {return 'P'}
'UpArrow' {return 'U1L'}
'Backspace' {return 'P'}
'PageUp' {return 'P'}
'RightArrow' {return 'N'}
'DownArrow' {return 'D1L'}
'PageDown' {return 'N'}
'Enter' {if ($buffer) {return $buffer}
else {return 'N'}}
'Home' {return 'F'}
'End' {return 'L'}
default {$char = $key.KeyChar
switch ($char) {',' {return '<'}
'.' {return '>'}
{$_ -match '(?i)[B-Z]'} {return $char.ToString().ToUpper()}
{$_ -match '[A#\+\-\d]'} {$buffer += $char}
default {$buffer = ""}}}}}}

$action = getaction

switch ($action.ToString().ToUpper()) {'F' {$pos = 0}
'N' {$next = getbreakpoint $pos; if ($next -lt $content.Count - 1) {$pos = $next + 1}
else {$pos = [Math]::Min($pos + $pageSize, $content.Count - 1)}}
'P' {$pos = [Math]::Max(0, $pos - $pageSize)}
'L' {$lastPageStart = [Math]::Max(0, [int][Math]::Floor(($content.Count - 1) / $pageSize) * $pageSize); $pos = $lastPageStart}

'<' {$currentSearchIndex = ($searchHits | Where-Object {$_ -lt $pos} | Select-Object -Last 1)
if ($null -eq $currentSearchIndex -and $searchHits -ne @()) {$currentSearchIndex = $searchHits[-1]; $statusmessage = "Wrapped to last match."; $errormessage = $null}
$pos = $currentSearchIndex
if (-not $searchHits -or $searchHits.Count -eq 0) {$errormessage = "No search in progress."; $statusmessage = $null}}
'S' {Write-Host -f green "`n`nKeyword to search forward from this point in the logs" -n; $searchTerm = Read-Host " "
if (-not $searchTerm) {$errormessage = "No keyword entered."; $statusmessage = $null; $searchTerm = $null; $searchHits = @(); continue}
$pattern = "(?i)$searchTerm"; $searchHits = @(0..($content.Count - 1) | Where-Object { $content[$_] -match $pattern })
if ($searchHits.Count -eq 0) {$errormessage = "Keyword not found in file."; $statusmessage = $null; $currentSearchIndex = -1}
else {$currentSearchIndex = $searchHits | Where-Object { $_ -gt $pos } | Select-Object -First 1
if ($null -eq $currentSearchIndex) {Write-Host -f green "No match found after this point. Jump to first match? (Y/N)" -n; $wrap = Read-Host " "
if ($wrap -match '^[Yy]$') {$currentSearchIndex = $searchHits[0]; $statusmessage = "Wrapped to first match."; $errormessage = $null}
else {$errormessage = "Keyword not found further forward."; $statusmessage = $null; $searchHits = @(); $searchTerm = $null}}
$pos = $currentSearchIndex}}
'>' {$currentSearchIndex = ($searchHits | Where-Object {$_ -gt $pos} | Select-Object -First 1)
if ($null -eq $currentSearchIndex -and $searchHits -ne @()) {$currentSearchIndex = $searchHits[0]; $statusmessage = "Wrapped to first match."; $errormessage = $null}
$pos = $currentSearchIndex
if (-not $searchHits -or $searchHits.Count -eq 0) {$errormessage = "No search in progress."; $statusmessage = $null}}
'C' {$searchTerm = $null; $searchHits.Count = 0; $searchHits = @(); $currentSearchIndex = $null}

'E' {$errIndex = ($content | Select-String 'ERROR LOGS:' | Select-Object -First 1).LineNumber
if ($errIndex) {$pos = $errIndex - 2; $statusmessage = "Jumped to ERROR LOGS:"; $errormessage = $null}
else {$errormessage = "'ERROR LOGS:' not found."; $statusmessage = $null}}
'D' {""; gc $script:file | more; return}
'X' {edit $script:file; "" ; return}
'M' {return logviewer}
'Q' {"`n"; return}
'U1L' {$pos = [Math]::Max($pos - 1, 0)}
'D1L' {$pos = [Math]::Min($pos + 1, $content.Count - $pageSize)}

default {if ($action -match '^[\+\-](\d+)$') {$offset = [int]$action; $newPos = $pos + $offset; $pos = [Math]::Max(0, [Math]::Min($newPos, $content.Count - $pageSize))}

elseif ($action -match '^(\d+)$') {$jump = [int]$matches[1]
if (-not $searchHits -or $searchHits.Count -eq 0) {$errormessage = "No search in progress."; $statusmessage = $null}
else {$targetIndex = $jump - 1
if ($targetIndex -ge 0 -and $targetIndex -lt $searchHits.Count) {$pos = $searchHits[$targetIndex]
if ($targetIndex -eq 0) {$statusmessage = "Jumped to first match."}
else {$statusmessage = "Jumped to match #$($targetIndex + 1)."}
$errormessage = $null}
else {$errormessage = "Match #$jump is out of range."; $statusmessage = $null}}}

elseif ($action -match '^A(\d+)$') {$requestedPage = [int]$matches[1]
if ($requestedPage -lt 1 -or $requestedPage -gt $totalPages) {$errormessage = "Page #$requestedPage is out of range."; $statusmessage = $null}
else {$pos = ($requestedPage - 1) * $pageSize}}

else {$errormessage = "Invalid input."; $statusmessage = $null}}}}
}

Export-ModuleMember -Function cleanlogfiles, lasterrors, log, logviewer

<#
## Overview

PowerShell's Start and Stop Transcript commands are great for logging, but the resulting files are difficult to read and they lack a centralized error tracking mechanism. So, this tool was created to alleviate some of those difficulties.

	• The log function allows you to start and stop transcript logging, or check on the status, if you're unsure of it's current state.
	• When logging is stopped, the module will append the last 100 errors before closing the transcript.
	• Logs will then be cleaned by removing any that are over 30 days old, stripping away the default headers and footers, adding visual separators and trimming error text.
	• A supplemental log viewer is also provided which features a file selection menu, internal file navigation and search capabilities.
## LastErrors 

This function recalls the last set of error messages that PowerShell generated, excluding command-not-found errors, formatted on screen for easier reading.
Optionally specify a # of errors to view. The default is 5.
This function is used at the end of the command to stop logging, in order to ensure that centralized error tracking is included.

Usage: lasterrors #
## Log

Turn transaction logging in PowerShell on or off, or check on its status.

Usage: log <start/stop/status> -help
## LogViewer
This logviewer will find all properly formatted .log files in the Transcripts directory and present them on screen for easy viewing.
If no file is provided, a menu of Transcripts organized by date will be presented for selection.

	Usage: logviewer <filename> -help

Once inside the viewer, the options include:

Navigation:

[F]irst page / [HOME]
[N]ext page / [PgDn] / [Right]
[+/-]# to move forward or back a specific # of lines / [Down] / [Up]
p[A]ge # to jump to a specific page
[P]revious page / [PgUp] / [Left]
[L]ast page / [END]

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
## License
MIT License

Copyright © 2025 Craig Plath

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell 
copies of the Software, and to permit persons to whom the Software is 
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in 
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN 
THE SOFTWARE.
##>
