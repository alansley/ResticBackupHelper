# ResticBackupHelper

A configurable Bash script to backup and prune data using [Restic](https://restic.net/).

To use the script, download it & make it executable with `chmod +x backupToNAS` then edit it to specify your own backup sets.

### Configuring Backup Sets

Each set is just the name of the set followed by the source and destination directories. For example, the included example sets are defined as:
```
# Map of backup sets: key=name, value=source:destination
# Adjust these for your use case.
add_backup_path "SomedData" "/mnt/SomeSourceFolder:/mnt/NAS/SomeDestinationFolder"
add_backup_path "WindowsGames" "/mnt/Windows/Games:/mnt/NAS/WindowsGamesBackup"
```

When running the script you can ONLY use the set names you've specified, so in this default case we could only call backup / prune on `SomeData` and `WindowsGames`.

### Example Usage

Calling the script without any arguments shows the usage details:
```
$ backupToNAS
Usage: backupToNAS {SomeData WindowsGames} [--dry-run] [--prune-after-backup|--prune-only]

Example: backupToNAS SomeData --prune-after-backup

If you add a pruning flag then ONLY the last restic backup will be kept at your backup destination.
```

So once you've added your set(s) and saved the changes, move it to somewhere it can be easily called like `/usr/local/bin` then run it, specifying the set you want - for example:
```
backupToNAS MySetName --prune-after-backup
```
