# Logging
PowerShell module to enhance logging with log file clean-up, retention limit and error tracking.

## Overview

PowerShell's Start and Stop Transcript commands are great for logging, but the resulting files are difficult to read and they lack a centralized error tracking mechanism. So, this tool was created to alleviate some of those difficulties.

	• The log function allows you to start and stop transcript logging, or check on the status, if you're unsure of it's current state.
	• When logging is stopped, the module will append the last 100 errors before closing the transcript.
	• Logs will then be cleaned by removing any that are over 30 days old, stripping away the default headers and footers, adding visual separators between command line interactions and leaving only the most important parts of the errors in each of the remaining files
## lasterrors 

This function recalls the last set of error messages that PowerShell generated, excluding command-not-found errors, formatted on screen for easier reading.

Optionally specify a # of errors to view. The default is 5.

This function is used at the end of the command to stop logging, in order to ensure that centralized error tracking is included.

	Usage: lasterrors #
## log

Turn transaction logging in PowerShell on or off, or check on its status.

	Usage: log <start/stop/status>
