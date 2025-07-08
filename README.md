[![AutoIt](https://avatars.githubusercontent.com/u/5172713?s=25&v=4)](https://github.com/autoit)

# Stop Services Processes

This script runs 24/7, periodically terminating processes and services required for Windows Update to download & install automatically. The script also terminates certain common installers. It is designed to be a "set it and forget it" tool for managing system behavior.

## Features

- **Hotkey Control**: Use hotkeys to start, pause, and stop the script.
- **Process Management**: Automatically closes a specified list of processes and logs the closures.
- **Service Management**: Checks for running services, stops them if necessary, and logs the action.
- **Robust Logging**: A corrected and reliable logging system writes all actions to a file and the console.
- **Window Event Handling**: Closes specific pop-up windows if they appear.
- **Process Priority**: Allows setting process priority for all instances of an application using a hotkey.
- **Customizable**: Easily configure log paths, log levels, the target process/service lists, and the tray icon.

## Hotkeys

- **`Shift + F1`**: Toggles the script's main loop between `on` and `off`. When toggled on, the script runs continuously, checking and closing processes and services as needed. Each press is logged with its action (starting/pausing).
- **`ScrollLock + PAUSE`**: Terminates the script immediately.
- **`Shift + Ctrl + 9`**: Opens a dialog to set the priority of a specific process by name.

## Logging

- **Log File**: The script logs events to `C:\login\closure_log.txt` by default. This path is generated from `%HOMEDRIVE%\login\closure_log.txt` and can be customized by editing the `Global $sLogFile` variable.
- **Log Levels**:
  - `0`: Errors only.
  - `1`: Basic logging.
  - `2`: Detailed logging (default).
- **Console Logging**: Enabled by default for real-time monitoring when running from an editor. To disable, set `Global $bLogToConsole = False`.

## Processes and Services Managed

### Processes
The script automatically terminates the following processes:
- `taskhostw.exe`
- `TrustedInstaller.exe`
- `TiWorker.exe`
- `CompatTelRunner.exe`
- `VSSVC.exe`
- `msiexec.exe`
- `msedge.exe`
- `helppane.exe`
- `net.exe`
- `vmcompute.exe`
- `msedgewebview2.exe`

### Services
The script stops the following services if they are running:
- `TrustedInstaller`
- `wuauserv` (Windows Update)
- `UsoSvc` (Update Orchestrator Service)
- `DoSvc` (Delivery Optimization)
- `WaaSMedicSvc` (Windows Update Medic Service)
- `sppsvc` (Software Protection Service)

Special handling is implemented for `sppsvc` to ensure proper termination.

## Setup

1. **Requirements**: Ensure you have [AutoIt](https://www.autoitscript.com/site/autoit/downloads/) installed if you want to run or edit the `.au3` source code. The compiled `.exe` from the Releases page does not require an AutoIt installation.

2. **Icon**: (Optional) To use a custom icon, edit `Global $iconfile` with the path to your desired `.ico` file.

3. **Log File**: (Optional) Edit `Global $sLogFile` to your preferred log file location.

4. **Processes and Services**: (Optional) Customize the `$sProcesses` and `$aServiceNames` arrays to include the processes and services you want to manage.

5. **Logging Configuration**: (Optional)
   - Adjust `$iLogLevel` (0=Errors only, 1=Basic logging, 2=Detailed logging).
   - Set `$bLogToConsole` to `True` or `False`.

## Usage

**The easiest way to use the script is to download the executable from the [`Releases`](https://github.com/SevWren/Win10-Stop-Services-Processes/releases) page and launch it.**

1. **DOWNLOAD EXE FROM [`RELEASES`](https://github.com/SevWren/Win10-Stop-Services-Processes/releases)**
2. Use **`Shift + F1`** to toggle the script between stopped/started states.
3. Use **`Shift + Ctrl + 9`** to set the priority of a specific process.
4. Check the log file for details on script actions.

## Miscellaneous

⚠️ The `_miscpopups()` function is specific to the author's system. This function checks for specific window classes (e.g., `TPleaseRegisterForm` for Advanced Renamer) and closes them. You can safely disable this if you don't use the targeted software.

To disable this function:
1. Comment out the line `_miscpopups()` inside the `ToggleScript()` function.
2. Comment out or delete the `_miscpopups()` function definition.

## Known Limitations

- The script requires administrative privileges to run (`#RequireAdmin`).
- The default paths for the icon and log file are hardcoded and may need to be updated for your system.

## Changelog

### v0.04 (Current)
- **Fix**: Overhauled the logging system to resolve a critical bug where log entries were not being written to the file after initialization.
- **Fix**: Corrected the startup logic to prevent a race condition where an old log file could be deleted without a new one being created.
- **Refactor**: Replaced `Local` with `Dim` for variables in the global scope to eliminate all AU3Check compiler warnings.
- **Refactor**: Removed redundant `ConsoleWrite` calls to streamline logging and prevent duplicate output.
- **Docs**: Updated README with corrected hotkeys (`Shift+Ctrl+9`), log paths, and a detailed new changelog entry.

### v0.03
- **Added**: Hotkey for setting process priority.
- **Improved**: Logging system now supports both file and console output.
- **Enhanced**: Error handling for `sppsvc` service termination.

### v0.02
- **Added**: Functionality to handle specific popups.
- **Improved**: Timer logic for periodic execution of service and process management functions.

### v0.01
- **Initial Release**: Basic functionality for stopping services and processes related to Windows Update.