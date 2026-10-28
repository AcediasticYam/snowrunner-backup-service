# SnowRunner Save Backup Service

A self-installing Powershell script which creates a Windows task-based save backup for the game SnowRunner (Steam version only).


## Background

I once lost three months of progress on a SnowRunner save due to a progressive corruption bug which eventually broke completely with a game update. This wasn't the first time that a save corruption happened with that game, so I wrote a short Powershell script to clone the entire save data directory.

I play on that save once a week with a friend, and he also wanted a copy. I extended it with an installer to help him set up a recurring Windows task.


> [!WARNING]
> Powershell scripts can cause harm to your PC. You should review all Powershell scripts before running them. This script is provided with no warranty or guarantee. The Windows task that is created by the installer uses `-NoProfile -NonInteractive -ExecutionPolicy Bypass` when running to allow the Powershell script to be run in the task.


## Requirements

* Windows 10/11
* User ability to execute Powershell scripts
* Steam version of SnowRunner


## Instructions

1. Download the script or clone this repository
2. Open a terminal in the directory containing the script
    * In the directory containing the script, right click and press *Open in Terminal*
3. Execute the command `Set-ExecutionPolicy -Scope Process Unrestricted`
    * This allows Powershell scripts to be executed for only the current terminal session

4. Execute the command `powershell .\SnowRunner-backup-install.ps1` to run the install script
    * You will be asked to confirm that you trust the script, review the script if you wish and press R to run once
5. A new script will be created in `Documents\My Games\SnowRunner\Backups` called `snowrunner-backup.ps1`. Backups will be stored in the same directory
6. The script will test the Windows task to ensure it functions correctly. If it does not, the service likely will not run. You can try running the `snowrunner-backup.ps1` script manually in a terminal (follow similar steps above for running the install) and inspect the output.

You will likely see a terminal prompt flash when the script runs; this is expected. If the task executes, a Windows notification/toast will alert you if the result was successful. Task runs output to `clone-log.txt` in the output directory.

**IMPORTANT**: This service does not automatically clean up the backup clones, which will steadily consume storage space. For reference, each backup for my personal game adds about 20 megabytes per week.

### Editing or Removing the Windows Task

A Windows task will be created to run the above backup script. This task can be found by pressing the Windows key and typing Task Scheduler. Once open, press *Task Scheduler Library* in the left pane. The service should appear there. The properties of the task can be edited to change when it runs and the task can be removed here if you no longer want it to execute. 


## Potential Improvements

I wrote this script in an afternoon before joining some friends, so it is rough around the edges. I thought of many ideas that could improve it or turn it into a generalized Steam game backup application while writing this documentation:

* Customizable date/time/intervals
    * The service is currently hardcoded to Wednesday at 8pm, weekly
* The install service currently only checks the operating system drive for the game and save data
    * The drive is configured at the top of the script using the SystemDrive. This could be hardcoded to another drive letter (e.g. `D:`) in a pinch
* This script could be used as a template for other games
    * The Steam ID for SnowRunner is hardcoded at the top of the script. The clone directory is the SnowRunner directory in `Documents\My Games`; this would need to be configurable as well
* Compress backups into zip archives
* Have a retention policy which cleans up old backup clones
* Create a proper installer
* Support other launchers (GoG, Epic)

I may get to it some day, but if not, feel free to run wild with these ideas!
