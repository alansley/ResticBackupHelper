#!/bin/bash
#
# Helper script to perform backups via Restic so you don't have to remember all the commandline switches.
echo "--- Restic Backup Helper v0.1 ---"

set -euo pipefail

declare -A BACKUP_PATHS=()
BACKUP_KEYS=()

# Helper function to add a backup set (required to print the backup sets in their defined order)
add_backup_set() {
    local key=$1
    local src=$2
    local dest=$3
    BACKUP_PATHS["$key"]="$src:$dest"
    BACKUP_KEYS+=("$key")
}


# **************************** IMPORTANT: ADD YOUR BACKUP SETS HERE! ******************************
#
# A backup set is just the name you want to give it, followed by the source directory, then the
# destination directory of the restic repo you're backing up to.
# 
# Generic Example:
#     add_backup_set "YourBackupSetName" "PathToSomeSourceFolder" "PathToSomeDestinationResticRepo"
#
# Concrete Example:
#     add_backup_set "Music" "/mnt/Storage/Music" "/mnt/NAS/Backups/Music"
#
# *************************************************************************************************


# Moan and bail if there are no backup sets
if [ "${#BACKUP_KEYS[@]}" -eq 0 ]; then
    echo "Error: No backup sets defined. Please edit this script to add backup sets before running."
    exit 1
fi

# --- Argument parsing ---
DRY_RUN=0      # Do not perform a dry-run / simulated backup by default
PRUNE_AFTER=0  # Do not prune after backup by default
PRUNE_ONLY=0   # Do not only perform a prune operation by default
VERBOSE=0      # Do not ask restic to be verbose by default

# Print usage instructions if we didn't get any args
if [ "$#" -lt 1 ]; then
    echo -n "Usage: $0 {"
    for key in "${BACKUP_KEYS[@]}"; do
        echo -n "$key "
    done
    cat <<EOF
} [--dry-run] [--prune-after-backup|--prune-only] [--verbose]

Edit this script before first use to add your backup set(s) to it.

A backup set is just a name for the set, the source directory, and the destination restic repo directory, e.g.,

    add_backup_set "Music" "/mnt/Storage/Music:/mnt/NAS/Backups/Music"
    
Then use it via:

    resticBackup.sh BackupSetName
    
So for the above example it would be:

    resticBackup.sh Music    

Options:
  --dry-run
      Simulates what would happen without actually performing the backup or pruning.
  --prune-after-backup
      Prune the restic repo to only keep the latest snapshot afer backup completes (not compatible with --dry-run or --prune-only).
  --prune-only
      Skip the backup step and prune the restic repo so that it only contains the latest snapshot (not compatible with --prune-after-backup).    
  --verbose
      Ask restic to provide detailed output when performing any of the above.
EOF
    exit 1
fi

# Grab the backup set to use from the first provided argument
BACKUP_SET="$1"
shift  # Drop the first argument (the backup set name to make life easier to parse any other args)

# Parse flags
while (( "$#" )); do
    case "$1" in
        --dry-run)
            DRY_RUN=1
            ;;
        --prune-after-backup)
            PRUNE_AFTER=1
            ;;
        --prune-only)
            PRUNE_ONLY=1
            ;;
        --verbose)
            VERBOSE=1
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
    shift
done

# --- Validate option combinations ---
if [[ "$PRUNE_AFTER" -eq 1 && "$DRY_RUN" -eq 1 ]]; then
    echo "Error: Cannot use --dry-run with --prune-after-backup as the backup step doesn't get performed so the simulated prune is likely to be inaccurate."
    exit 1
fi

if [[ "$PRUNE_ONLY" -eq 1 && "$PRUNE_AFTER" -eq 1 ]]; then
    echo "Error: Cannot use --prune-only and --prune-after-backup together."
    exit 1
fi

# Validate backup set
if [[ ! ${BACKUP_PATHS[$BACKUP_SET]+_} ]]; then
    echo "Error: Invalid backup set '$BACKUP_SET'"
    echo "Valid options: ${!BACKUP_PATHS[*]}"
    exit 1
fi

# --- Check restic availability ---
if ! command -v restic >/dev/null 2>&1; then
    echo "Error: 'restic' command not found in PATH. Please install restic."
    exit 1
fi

# Extract source and destination paths
IFS=':' read -r SRC DEST <<< "${BACKUP_PATHS[$BACKUP_SET]}"

# Moan and bail if source doesn't exist or is empty
if [ ! -d "$SRC" ] || [ -z "$(ls -A "$SRC")" ]; then
    echo "Error: Source path $SRC is empty or missing. Aborting to prevent empty backup."
    exit 1
fi

# Get the restic repo password as we need to re-use it for prune, and we also need it to check if the destination is a valid restic repo
read -s -p "Enter restic repository password: " RESTIC_PASSWORD
echo

# --- Check that our destination is a valid restic repository ---
CHECK_REPO_OUTPUT=$(restic --repo "$DEST" snapshots --password-file <(echo "$RESTIC_PASSWORD") 2>&1) || {
    if echo "$CHECK_REPO_OUTPUT" | grep -q "wrong password or no key found"; then
        # NOTE: Restic does not currently support localization, so checking for this English error string is safe-ish.
        echo "Error: Incorrect password for restic repository at '$DEST'."
    else
	echo
        echo "$CHECK_REPO_OUTPUT"
        echo
        echo "Hint: If you want to backup to a new restic repo then make sure the directory doesn't already exist then initialize it to create using:"
        echo "  restic init --repo \"$DEST\""
    fi
    unset RESTIC_PASSWORD
    exit 1
}

# --- Build additional command option args ---
args=()

if [[ "$DRY_RUN" -eq 1 ]]; then
    args+=("--dry-run")
fi

if [[ "$VERBOSE" -eq 1 ]]; then
    args+=("--verbose")
fi

# --- If not prune-only, do backup ---
if [ "$PRUNE_ONLY" -eq 0 ]; then
    echo "Starting backup of $SRC to $DEST"
    restic --repo "$DEST" backup "$SRC" --password-file <(echo "$RESTIC_PASSWORD") "${args[@]}"
fi

# --- Prune if requested ---
if [[ "$PRUNE_ONLY" -eq 1 || "$PRUNE_AFTER" -eq 1 ]]; then
    echo "Pruning old snapshots for $DEST (keeping last 1)..."
    restic forget --repo "$DEST" --keep-last 1 --prune --password-file <(echo "$RESTIC_PASSWORD") "${args[@]}"
fi

unset RESTIC_PASSWORD
exit 0
