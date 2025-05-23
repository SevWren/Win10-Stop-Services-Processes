TLDR - I got tired of windows 10 updates running nonstop only to only fail on a certain patch.  

Script runs 24/7 periodacly terminating processes/services required for windows update to download & install automaticaly. 
Script also terminates certain installers. 

This AutoIt script is designed to manage and control specific processes and services on a Windows 10 system.
It handles the unattended closing of processes and stopping of services related to Windows 10 Update & background software installs, logs events to file, and handles specific window events automatically.

## Features
- **Hotkey Control**: Use hotkeys to start, pause, and stop the script.
- **Process Management**: Automatically closes specified processes and logs their closures.
- **Service Management**: Checks for running services, stops them if necessary, and logs the closure.
- **Smart Logging**: Only logs when actual actions are taken (process/service closures).
- **Window Event Handling**: Closes specific windows if they appear.

## Hotkeys
- **`{F1}`**: Toggles script between off and on. When toggled on, the script runs continuously, checking and closing processes and services as needed. Each F1 press is logged with its action (starting/pausing).
- **`{ScrollLock}{PAUSE}`**: Terminates the script immediately.

## Script Overview

### Globals

- `$sProcesses`: An array of processes to be closed automatically.
- `$bScriptRunning`: A flag to track the running state of the script.
- `$iLastStopServices`: Tracks the last time the `_stopservicescustom()` function was called.
- `$iLastStopProcesses`: Tracks the last time the `_CloseInstaller()` function was called.
- `$sLogFile`: The path to the log file where actions are recorded.
- `$iLogLevel`: Controls the verbosity of logging (0=Errors only, 1=Basic logging, 2=Detailed logging).
- `$bLogToConsole`: Enables/disables console output alongside file logging.

### Main Loop

The script runs indefinitely, waiting for hotkey inputs to control the flow.
When activated, it periodically checks for running processes and services, closes them if they exist, and logs the actions taken.

### Functions

- **ToggleScript()**: Handles starting and pausing the script. Logs F1 hotkey presses and their actions (starting/pausing).
- **_CloseInstaller()**: Iterates over the `$sProcesses` array, closing each process that is running. Only logs when processes are actually found and closed.
- **_stopservicescustom()**: Checks for specific services, stops them if running. Only logs when services are actually found and stopped.
- **_LogMessage()**: Enhanced logging function that supports different message types and log levels.
- **CheckElapsedTime($iStartTime, $iInterval)**: Calculates if the specified time interval has passed since the last function call.
- **_AdvancedRenamer()**: Checks for a specific window class and closes it if found.
- **_exit()**: Logs the termination of the script and exits.

## Setup

1. **Requirements**: Ensure you have AutoIt installed on your system.

2. **Icon**: (Optional) To use a custom icon for the app in your systray edit `Global $iconfile = "G:\Users\mmuel\OneDrive\Documents\AutoIT\ff7.ico"` with the path to your desired tray icon file.

3. **Log File**: Edit `Global $sLogFile = "G:\login\closure_log.txt"` to your preferred log file location.
      
4. **Processes and Services**: (Optional) Customize the `$sProcesses` and `$aServiceNames` arrays to include the processes and services you want to manage.
   When declaring the Global variable `$sProcesses[11]`, `11` must match the number of processes declared.

5. **Logging Configuration**: (Optional)
   - Adjust `$iLogLevel` (0=Errors only, 1=Basic logging, 2=Detailed logging)
   - Set `$bLogToConsole` to True/False to enable/disable console output

## Usage
1. Run the script with AutoIt/SciTe/ETC or compile it
2. Use F1 to toggle the script between stopped/started states (actions are logged)
3. Check the log file for details about:
   - F1 hotkey presses (start/pause actions)
   - Process closures (only when processes are found and closed)
   - Service stops (only when services are found and stopped)
4. Hover over the icon in the system tray to see the current script state

## MISC
⚠️The custom function: _AdvancedRenamer() is specific to my system.
To Disable Change The variable: "Global $bEnableAdvancedRenamer = 1" to  "Global $bEnableAdvancedRenamer = 0"

The custom function `_AdvancedRenamer()` is specific to my system. To remove this function:
- Remove/comment out the `_AdvancedRenamer()` function
- Remove the call to `_AdvancedRenamer()` in the `_togglescript()` function