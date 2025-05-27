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
