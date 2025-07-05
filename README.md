# ResticBackupHelper

A Bash script to easily backup and prune data using [Restic](https://restic.net/).

To use the script, download it then edit it to specify your own backup sets, then make it executable with `chmod +x resticBackup.sh` and run it.

### Configuring Backup Sets

Each set is just the name of the set followed by the source directory and the destination restic repo directory. For example:
```
add_backup_set "Music" "/mnt/Storage/Music" "/mnt/NAS/Backups/Music"
```

When running the script you can ONLY use the set names you've specified, so in this example we could only call backup / prune on the `Music` set.

### Options

The following optional arguments can be used:
```
  --dry-run
      Simulates what would happen without actually performing the backup or pruning.
  --prune-after-backup
      Prune the restic repo to only keep the latest snapshot afer backup completes (not compatible with --dry-run or --prune-only).
  --prune-only
      No backup, just prune the restic repo to only contain the latest snapshot (not compatible with --dry-run or --prune-after-backup).    
  --verbose
      Ask restic to provide detailed output when performing its operations.
```

### Example Usage

To backup the above example set and then prune the restic repo so that it only contains the latest snapshot we could use:
```
$ resticBackup.sh Music --prune-after-backup
```
