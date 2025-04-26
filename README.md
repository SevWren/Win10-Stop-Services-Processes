[![AutoIt](https://avatars.githubusercontent.com/u/5172713?s=25&v=4)](https://github.com/autoit)

# Stop Services Processes

TLDR - I got tired of Windows 10 updates running nonstop only to only fail on a certain patch.

This script runs 24/7, periodically terminating processes and services required for Windows Update to download & install automatically. The script also terminates certain installers.

This AutoIt script is designed to manage and control specific processes and services on a Windows 10 system.
It handles the unattended closing of processes and stopping of services related to Windows Update & background software installs, logs events to file, and handles specific window events automatically.

## Features

- **Hotkey Control**: Use hotkeys to start, pause, and stop the script.
- **Process Management**: Automatically closes specified processes and logs their closures.
- **Service Management**: Checks for running services, stops them if necessary, and logs the closure.
- **Smart Logging**: Only logs when actual actions are taken (process/service closures).
- **Window Event Handling**: Closes specific windows if they appear.
- **Process Priority**: Allows setting process priority using a hotkey.
- **Customizable Logging**: Supports both file and console logging with adjustable log levels.
- **Icon Customization**: Allows setting a custom tray icon for the script.

## Hotkeys

- **`Shift & {F1}`**: Toggles script between off and on. When toggled on, the script runs continuously, checking and closing processes and services as needed. Each F1 press is logged with its action (starting/pausing).
- **`{ScrollLock} & {PAUSE}`**: Terminates the script immediately.
- **`Shift & 9`**: Opens a dialog to set the priority of a specific process.

## Logging

- **Log File**: The script logs events to a file located at `G:\login\closure_log.txt` by default. This can be customized by editing the `Global $sLogFile` variable in the script.
- **Log Levels**:
  - `0`: Errors only.
  - `1`: Basic logging.
  - `2`: Detailed logging (default).
- **Console Logging**: Enabled by default. To disable, set `Global $bLogToConsole = False`.

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

1. **Requirements**: Ensure you have [AutoIt](https://github.com/autoit) installed on your system if you want to run the `.au3` source code directly.

2. **Icon**: (Optional) To use a custom icon for the app in your systray, edit `Global $iconfile = ""` with the path to your desired tray icon file.

3. **Log File**: Edit `Global $sLogFile = ""` to your preferred log file location.

4. **Processes and Services**: (Optional) Customize the `$sProcesses` and `$aServiceNames` arrays to include the processes and services you want to manage.
   When declaring the Global variable `$sProcesses[11]`, `11` must match the number of processes declared.

5. **Logging Configuration**: (Optional)
   - Adjust `$iLogLevel` (0=Errors only, 1=Basic logging, 2=Detailed logging).
   - Set `$bLogToConsole` to `True` or `False` to enable or disable console output.

6. **Hotkey for Process Priority**: Use `Ctrl + 9` to set the priority of all instances of a process by name.

## Usage

**To run the script, download the executable from [`Releases`](https://github.com/SevWren/Win10-Stop-Services-Processes/releases/tag/Working) and launch it. No AutoIt installation is required to run the .exe!**

1. **DOWNLOAD EXE FROM [`RELEASES`](https://github.com/SevWren/Win10-Stop-Services-Processes/releases/tag/Working)**
2. Use Shift & F1 to toggle the script between stopped/started states (actions are logged).
3. Use `Ctrl + 9` to set the priority of a specific process.
4. Check the log file for details about:
   - F1 hotkey presses (start/pause actions).
   - Process closures (only when processes are found and closed).
   - Service stops (only when services are found and stopped).
   - Priority changes for processes.
5. Hover over the icon in the system tray to see the current script state.

## Miscellaneous

⚠️ The `_miscpopups()` function is specific to the author's system. This function checks for specific window classes (e.g., `TPleaseRegisterForm`) and closes them if found.

To disable this function:

1. Comment out the line `_miscpopups()` inside the `ToggleScript()` function.
2. Comment out the `_miscpopups()` function definition itself.

## Known Limitations

- The script requires administrative privileges to run (`#RequireAdmin` directive).
- The default paths for the icon and log file are hardcoded and may need to be updated for your system.
- The script is designed for Windows 10 and may not work as intended on other versions of Windows.

## Changelog

### v0.03
- **Added**: Hotkey `^9` for setting process priority.
- **Improved**: Logging system now supports both file and console output.
- **Enhanced**: Error handling for `sppsvc` service termination.
- **Updated**: `_miscpopups()` function to handle additional window classes.
- **Fixed**: Log file initialization to ensure proper directory creation and logging.

### v0.02
- **Added**: `_AdvancedRenamer()` function to handle specific popups (now replaced by `_miscpopups()`).
- **Improved**: Timer logic for periodic execution of service and process management functions.

### v0.01
- **Initial Release**: Basic functionality for stopping services and processes related to Windows Update.
