$steamAppId = "1465360";
$windowsDrive = (Get-WmiObject Win32_OperatingSystem).SystemDrive;

Write-Host "Installing Snowrunner Backup Service"
$psPath = (Get-Command "powershell.exe").Path
Write-Host "Found PowerShell - $psPath"
$gameDir = [Environment]::GetFolderPath("MyDocuments") + "\My Games\SnowRunner";
if (Test-Path -Path $gameDir) {
    Write-Host "Found SnowRunner directory"
} else {
    Write-Host -f red "ERROR: Could not find SnowRunner directory in My Games"
    Exit
}

try {
    if ((Test-Path -Path ($gameDir + "\Backups")) -eq $false) {
        New-Item -ItemType "directory" -Path ($gameDir + "\Backups") > $null
        Write-Host "Created Backups directory"
    } else {
        Write-Host "Backups directory exists"
    }
    $gameDir = $gameDir + "\Backups"
} catch {
    Write-Host -f red ("ERROR: Exception encountered creating backup directory: " + $_.Exception.Message)
    Exit
}

$paths
if (Test-Path -Path "$windowsDrive\Program Files\Steam") {
    $paths = Get-ChildItem -Path "$windowsDrive\Program Files\Steam" -Include "$steamAppId" -Recurse
} elseif (Test-Path -Path "$windowsDrive\Program Files (x86)\Steam") {
    $paths = Get-ChildItem -Path "$windowsDrive\Program Files (x86)\Steam" -Include "$steamAppId" -Recurse
} else {
    Write-Host -f red "ERROR: Unable to find Steam directory in program files"
    Exit
}

if ($paths.Length -eq 0) {
    Write-Host -f red "ERROR: Unable to find Steam remote base directory"
    Exit
}

$foundPath = $false;

foreach ($path in $paths) {
    if (Test-Path -Path "$path\remote") {
        $foundPath = "$path\remote"
    }
}

if ($foundPath -eq $false) {
    Write-Host -f red "ERROR: Unable to find Steam remote directory"
    Exit
}

Write-Host "Found Steam remote directory for SnowRunner: $foundPath"
Write-Host ""
Write-Host "Creating Scheduled Task"

$taskName = "snowrunner-backup"

if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
    Write-Host "Task already exists - deleting old task"
    Try {
        Unregister-ScheduledTask -TaskName $taskName -TaskPath "\" -Confirm:$false -ErrorAction Stop
    } Catch {
        Write-Host -f red "ERROR: Unable to delete registered task '$taskName'. Please manually remove the task in Task Scheduler."
        Exit
    }
}

$arguments = "-NoProfile -NonInteractive -ExecutionPolicy Bypass -file `"$gameDir\snowrunner-backup.ps1`""
$action = New-ScheduledTaskAction -Execute $psPath -Argument $arguments
$trigger = New-ScheduledTaskTrigger -Weekly -At 8pm -DaysOfWeek Wednesday
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable 

$task = New-ScheduledTask -Action $action -Trigger $trigger -Settings $settings
Register-ScheduledTask $taskName -InputObject $task > $null

Write-Host "Successfully registered task"

$backupScript = @"
function Show-Notification {
    [cmdletbinding()]
    Param (
        [string]
        `$ToastTitle,
        [string]
        [parameter(ValueFromPipeline)]
        `$ToastText
    )

    [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > `$null
    `$Template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)

    `$RawXml = [xml] `$Template.GetXml()
    (`$RawXml.toast.visual.binding.text|where {`$_.id -eq "1"}).AppendChild(`$RawXml.CreateTextNode(`$ToastTitle)) > `$null
    (`$RawXml.toast.visual.binding.text|where {`$_.id -eq "2"}).AppendChild(`$RawXml.CreateTextNode(`$ToastText)) > `$null

    `$SerializedXml = New-Object Windows.Data.Xml.Dom.XmlDocument
    `$SerializedXml.LoadXml(`$RawXml.OuterXml)

    `$Toast = [Windows.UI.Notifications.ToastNotification]::new(`$SerializedXml)
    `$Toast.Tag = "PowerShell"
    `$Toast.Group = "PowerShell"
    `$Toast.ExpirationTime = [DateTimeOffset]::Now.AddMinutes(1)

    `$Notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("PowerShell")
    `$Notifier.Show(`$Toast);
}

`$gameRemotePath = "$($foundPath)"
Set-Location "$($gameDir)"
`$date = Get-Date -UFormat "+%Y-%m-%dT%H_%M_%S"
"Running copy command - `$date" | Out-File -Append -FilePath .\clone-log.txt
Try {
    `$basePath = Get-Location
    Copy-Item -Path "`$gameRemotePath" -Destination "`$basePath\remote-`$date" -Recurse -ErrorAction Stop
    "Copied file to `$basePath\remote-`$date" | Out-File -FilePath ".\clone-log.txt" -Append
    Show-Notification "SnowRunner Backup Service" "Backup created successfully."
} 
Catch {
    Write-Host -f red "Encountered Error:"`$_.Exception.Message
    "An error occurred during copy operation:" | Out-File -Append -FilePath ".\clone-log.txt"
    `$Error[0] | Out-File -FilePath ".\clone-log.txt" -Append
    Show-Notification "SnowRunner Backup Service" "Backup error - check clone-log.txt log file."
}
"@

try {
    $backupScript | Out-File -FilePath ($gameDir + "\snowrunner-backup.ps1") -ErrorAction Stop
} catch {
    Write-Host -f red "ERROR: Unable to write backup script to Backups directory"
    Exit
}

Write-Host ""
Write-Host "Testing backup task"
Start-ScheduledTask $taskName

Write-Host "Task started, waiting for result"
$date = (Get-Date -Format "yyyy-MM")

$foundBak = $false
for ($i = 0; $i -le 60 -and !$foundBak; $i++) {
    $paths = Get-ChildItem -Path $gameDir -Recurse -Directory -Force

    foreach ($path in $paths) {
        $dateStr = $path.Name.replace('remote-', '').replace('_', ':')
        $date = Get-Date -Date $dateStr
        $currDate = Get-Date
        $diff = $currDate.Subtract($date).TotalSeconds

        if ($diff -le 60) {
            $foundBak = $true
            Break
        }
    }

    Start-Sleep -Seconds 1
}

if ($foundBak -eq $false) {
    Write-Host -f yellow "WARN: Unable to find backup from task test; task may not be set up properly"
}

Write-Host ""
Write-Host "Installation complete"