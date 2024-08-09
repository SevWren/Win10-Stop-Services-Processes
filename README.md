# Win10-Stop-Services-Processes
Script that runs 24/7 preventing processes/services required for windows update to run. 


This AutoIt script is designed to manage and control specific processes and services on a Windows 10 system.
It handles the unattended closing of processes and stopping of services related to Windows 10 Update & background software installs, logs events to file, and handles specific window events automatically.

## Features
- **Hotkey Control**: Use hotkeys to start, pause, and stop the script.
- **Process Management**: Automatically closes specified processes and logs their closures.
- **Service Management**: Checks for running services, stops them if necessary, and logs the closure.
- **Logging**: All process and service closures are logged with a timestamp.
- **Window Event Handling**: Closes specific windows if they appear.

## Hotkeys
- **`{F1}`**: Toggles script between off and on. When toggled on, the script runs continuously, checking and closing processes and services as needed.
- **`{ScrollLock}{PAUSE}`**: Terminates the script immediately.

## Script Overview

### Globals

- `$sProcesses`: An array of processes to be closed automatically.
- `$bScriptRunning`: A flag to track the running state of the script.
- `$iLastStopServices`: Tracks the last time the `_stopservicescustom()` function was called.
- `$iLastStopProcesses`: Tracks the last time the `_CloseInstaller()` function was called.
- `$sLogFile`: The path to the log file where closures are recorded.

### Main Loop

The script runs indefinitely, waiting for hotkey inputs to control the flow.
When activated, it periodically checks for running processes and services, closes them if they exist, and logs the actions taken.

### Functions

- **ToggleScript()**: Handles starting and pausing the script. It checks the elapsed time between calls and determines whether to close processes and services.
- **_CloseInstaller()**: Iterates over the `$sProcesses` array, closing each process that is running and logging the closure.
- **_stopservicescustom()**: Checks for specific services, stops them if they are running, and logs the closure.
- **CheckElapsedTime($iStartTime, $iInterval)**: Calculates if the specified time interval has passed since the last function call.
- **LogClosure($sName, $sType)**: Logs the date and time when a process or service is closed.
- **_AdvancedRenamer()**: Checks for a specific window class and closes it if found.
- **_exit()**: Logs the termination of the script and exits.

## Setup

1. **Requirements**: Ensure you have AutoIt installed on your system.  The current compiled version won't run directly as the log location is specific to my system currently.

2. **Icon**: (Optional) To use a custom icon for the app in your systray edit `Global $iconfile = "G:\Users\mmuel\OneDrive\Documents\AutoIT\ff7.ico"` with the path to your desired tray icon file.

3. **Log File**: Edit `Global $sLogFile = "C:\Users\User\Desktop\closure_log.txt" ;Log File Location` to the path with filename & ext to your preferred log file location.
      
4. **Processes and Services**: (Optional)  Customize the `$sProcesses` and `$aServiceNames` arrays to include the processes and services you want to manage.
   When declaing the Global variable  $sProcesses[11]   `11` must match the number of processes declared

## Usage
1. Run the script with AutoIt/SciTe/ETC / or compile
2. Use the hotkeys to control the script mode. Stopped/Started
3. Check the log file for details about process and service closures.
4. Hovering over the icon in the system tray will update with the part of the script that is currently running

## MISC

The custom function:   _AdvancedRenamer()  is specific to my system.  To remove this function;
        Remove / comment out func _AdvancedRenamer() 
        Remove call to _AdvancedRenamer() in the _togglescript() function