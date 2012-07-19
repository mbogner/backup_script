#!/bin/bash

# some global variables that are needed in the functions below
MONTH=`date +%m`
DOM=`date +%d`
DOW=`date +%w`
DS1970=$(( $(date +%s) / 3600 / 24 ))

#
# print a log message with actual timestamp
#
function local_log {
	echo "`date`: $1"
}

#
# check argument count, print usage and exit if necessary
#
# @param cnt
#	real param count
# @param exp
#	expected at least this count of arguments
# @param msg
#	message to display
#
function local_usage {
	local CNT=$1
	local EXP=$2
	local MSG=$3
	if [ $CNT -lt $EXP ]; then
		local_log "USAGE: $MSG"
		exit 1
	fi
}

#
# Execute a command and check exit code. Exit program if exit code is unexpected.
#
# @param command
#	command to exectue
# @param expected
#	expected exit code of the given command
# @param output
#	optional output file
#
function execute {
	local_usage $# 2 "execute <command> <expected>"
	local COMMAND=$1
	local EXPECTED=$2

	if [ $# -eq 3 ]; then
		local_log "writing output to $OUTPUT"
		local OUTPUT=$3
	else
		local OUTPUT=$LOG
	fi

	local_log "executing: $COMMAND"
	if [ "$DEBUG" == 'debug' ]; then
		local_log "skipped as we are debugging"
	else
		$($COMMAND >> $OUTPUT 2>> $ERR)
		local RES=$?
		if [ $RES -ne $EXPECTED ]; then
			local_log "command gave result $RES - expected $EXPECTED"
			local_log "backup failed - see $LOG" >> $OVERVIEW
			exit 1
		fi
	fi
}

#
# remove old link if it exists and link to target
#
# @param old
#	where to place the link
# @param new
#	the link target
#
function recreate_link {
	local_usage $# 2 "recreate_link <softlink> <target>"
	local OLD=$1
	local NEW=$2
	local_log "recreating current link $OLD"
	execute "rm -f $OLD" 0
	execute "ln -s $NEW $OLD" 0
	local_log "$OLD now points to $NEW"
}

#
# dump a postgre database to a file named like the db-name in a folder.
# use .pgpass for password.
#
# @param db
#	database name to backup
# @param username
#	username to use for the backup
# @param subfolder
#	subfolder of BKP to place the db dump
#
function backup_database_pg {
	local_usage $# 3 "backup_database_pg <database> <username> <subfolder>"
	local DB=$1
	local USERNAME=$2
	local SUBFOLDER=$3

	local TARGET="$BKP/$SUBFOLDER/${DB}.sql.$DOM"
	local LINK="$BKP/$SUBFOLDER/current_${DB}.gz"

	create_folder_ifneeded $SUBFOLDER

	local_log "dumping pg database $DB to $TARGET as user $USERNAME"
	execute "$PGDUMP -U $USERNAME -w $DB" 0 $TARGET
	execute "rm -f ${TARGET}.gz" 0
	execute "gzip $TARGET" 0

	recreate_link $LINK "$TARGET.gz"
	local_log "$DB backup done"
}

#
# dump a mysql database to a file named like the db-name in a folder
#
# @param db
#       database name to backup
# @param username
#       username to use for the backup
# @param password
#	password for the user
# @param subfolder
#       subfolder of BKP to place the db dump
#
function backup_database_mysql {
	local_usage $# 4 "backup_database_mysql <database> <username> <password> <subfolder>"
        local DB=$1
        local USERNAME=$2
        local PASSWORD=$3
        local SUBFOLDER=$4

        local TARGET="$BKP/$SUBFOLDER/${DB}.sql.$DOM"
        local LINK="$BKP/$SUBFOLDER/current_${DB}.gz"

	create_folder_ifneeded $SUBFOLDER

        local_log "dumping mysql database $DB to $TARGET as user $USERNAME"
        execute "$MYDUMP -u$USERNAME -p$PASSWORD $DB" 0 $TARGET
	execute "rm -f ${TARGET}.gz" 0
	execute "gzip $TARGET" 0
	local_log "dumped to $TARGET"

	recreate_link $LINK "$TARGET.gz"
        local_log "$DB backup done"
}

#
# create a subfolder in BKP if it does not exist
#
# @param name
#	name of the folder
#
function create_folder_ifneeded {
	local_usage $# 1 "create_folder_ifneeded <name>"
	local TMP="$BKP/$1"
	if [ ! -d $TMP ]; then
		local_log "creating $TMP as it does not exist"
		execute "mkdir -p $TMP" 0
	fi
}

#
# Hold a second backup of a folder and hardlink all files in rotation for not loosing files.
# This does not help to recover changed files. Use only to make sure not to lose files.
# Rotation is done by actual month.
#
# @param name
#	local folder-name to hold local full backup
# @param folder
#	full path to folder we want to backup with / at the end
# @param params
#	special params for rsync, e.g. for more excludes
#
function backup_folder {
	local_usage $# 2 "backup_folder <name> <folder> (<params>)"
	local NAME=$1
	local FOLDER=$2
	local PARAMS=$3

	local TARGET="$BKP/$NAME.$DOM"
	local LINK="$BKP/current_$NAME"

	create_folder_ifneeded $NAME

	local_log "updating local copy from $FOLDER to $BKP/$NAME"
	execute "$RSYNC -avu $PARAMS --delete --delete-excluded $FOLDER $BKP/$NAME/" 0

	local_log "recreating folder $TARGET"
	execute "rm -rf $TARGET" 0
	execute "cp -al $BKP/$NAME $TARGET" 0

	recreate_link $LINK $TARGET	
	local_log "backup folder $NAME done"
}

#
# Sync to backup dir and hardlink to older backups if files are unchanged.
#
# @param name
#	base name of the backup folder
# @param number
#	number of copies to keep
# @param folder
#	folder to backup with / at the end for rsync
# @param params
#	special parameters for rsync
#
function backup_folder_full {
	local_usage $# 3 "backup_folder_full <name> <keep-number> <folder> (<params>)"
        local NAME=$1
	local NUMBER=$2
        local FOLDER=$3
        local PARAMS=$4

	local ACTUAL=`expr $DS1970 % $NUMBER`
	local TARGET="$NAME.$ACTUAL"
	local LINK="$BKP/current_$NAME"

	local_log "updating $TARGET with content from $FOLDER and keeping $NUMBER backups"

	local_log "updating local copy nr $ACTUAL (day $DS1970) from $FOLDER to $BKP/$TARGET and creating link $LINK"
	create_folder_ifneeded $TARGET

	local LINK_DEST=$(readlink $LINK)
	local LINK_DEST_VAL="--link-dest=$LINK_DEST"
	if [ "$LINK_DEST" -eq "" ]; then
		LINK_DEST_VAL=""
	fi

	execute "$RSYNC -avu $PARAMS $LINK_DEST_VAL --delete --delete-excluded $FOLDER $BKP/$TARGET/" 0

	recreate_link $LINK "$BKP/$TARGET"
	local_log "full backup folder $NAME done"
}

#
# remove all files in given folder that match pattern
#
# @param folder
#	folder to empty
# @param pattern
#	pattern for files to remove
#
function empty_folder {
	local_usage $# 2 "empty_folder <folder> <pattern>"
	local FOLDER=$1
	local PATTERN=$2
	local_log "deleting all $PATTERN in $FOLDER"
	execute "find $FOLDER -name $PATTERN -exec rm -rf {} \;"
}

#
# rsync a folder to any remote destination using a password file
#
# @param passfile
#	password file for rsync
# @param source
#	source to sync from
# @param target
#	target for sync
# @param params
#	special params for rsync like extra excludes
#
function sync2remote {
	local_usage $# 3 "sync2remote <password-file> <source> <target> (<params>)"
	local PASSFILE=$1
	local SOURCE=$2
	local TARGET=$3
	local PARAMS=$4
	local_log "syncing $SOURCE to $TARGET"
	execute "$RSYNC -avuz $PARAMS --delete --delete-excluded --password-file=$PASSFILE $SOURCE $TARGET" 0
	local_log "sync of $SOURCE done"
}

#
# wrapper for rotated backups. do NOT use a / at the end of source as this is added automatically
#
function sync2remote_rotated {
	local_usage $# 4 "sync2remote_rotated <keep-files> <password-file> <source> <target> (<params>)"
	ACTUAL=`expr $DS1970 % $1`
	sync2remote $2 "$3.$ACTUAL/" $4 $5
}

#
# create a tgz file from a folder in BKP and place it in the target folder.
# the target file is named as the source folder with .tgz
#
# @param src
#	folder that should be compressed
# @param target
#	folder to place the new file to
#
function tar_target {
	local_usage $# 2 "tar_target <src> <target-dir> (<src-addon>)"
        local SRC="$BKP/$1$3"
        local TARGET="$2/$1.tgz"

        local OLDDIR=`pwd`
        execute "cd $BKP" 0

        local_log "taring $SRC to $TARGET"
        execute "rm -f $TARGET" 0
        execute "tar -czf $TARGET $SRC" 0
	local_log "$TARGET created"

        execute "cd $OLDDIR" 0

        local_log "taring $SRC done"
}

#
# wrapper to tar rotated folders to a target without rotation
#
function tar_target_rotated {
	local_usage $# 3 "tar_target_rotated <keep-files> <src> <target-dir>"
	local ACTUAL=`expr $DS1970 % $1`
	tar_target $2 $3 ".$ACTUAL"
}

#
# remove files/folders that were not updated last month as there were no such days.
# used for the DOM rotation and hardlinked files.
#
function cleanup_last_month {
	if [ "$DEBUG" != 'debug' ]; then
		if [ $DOM -ne 1 ]; then
			local_log "Only starting cleanup on first day of month"
			return
		fi
	fi

	local_log "Cleaning up last month - actual $MONTH"

	local DATA[1]="" #dez=31
	local DATA[2]="" #jan=31
	if [ $MONTH -eq 3 ]; then #feb=28
		YEAR=`date +%Y`
		LEAP=`expr $YEAR % 4`
		local_log "check for leap year (0=true): $LEAP"
		if [ $LEAP -eq 0 ]; then
			local_log "we have a leap year"
			local DATA[3]="30 31"
		else
			local_log "no leap year"
			local DATA[3]="29 30 31"
		fi
	fi
	local DATA[4]="" #mar=31
	local DATA[5]="31" #apr=30
	local DATA[6]="" #mai=31
	local DATA[7]="31" #jun=30
	local DATA[8]="" #jul=31
	local DATA[9]="" #aug=31
	local DATA[10]="31" #sep=30
	local DATA[11]="" #oct=31
	local DATA[12]="31" #nov=30

	local TOCLEAN=${DATA[$MONTH]}
	local_log "days from last month to remove: $TOCLEAN"
	for day in $TOCLEAN; do
		if [ $# -lt 1 ]; then
			local_log "WARNING: no folders given for cleanup"
			return
		else
			for arg in $*; do
				local FILE=$BKP/${arg/\%DAY\%/$day}
				local_log "cleanup day $day with pattern $arg => $FILE"
				execute "rm -rf $FILE" 0
			done
		fi
	done
}

function sync_from_remote {
	local_usage $# 4 "backup_offsite <name> <username> <remote-host> <linksource>"
        local NAME=$1
	local USERNAME=$2
        local HOST=$3
        local LINKSOURCE=$4
	local PARAMS=$5

	local CONSTR="${USERNAME}@${HOST}"

        local MAILS=$(ssh $CONSTR "readlink $LINKSOURCE")
        if [ $? -ne 0 ] || [ "$MAILS" == '' ]; then local_log "could not read link: $?"; exit 1; fi

        # last numbers show the version
        local NR=$(echo $MAILS | sed 's/^.*\.\([0-9]*\)$/\1/')
        if [ "$NR" == '' ]; then local_log "could not get number of backup from: '$MAILS'"; exit 2; fi

        local TARGET="$BKP/$HOST/$NAME.$NR"
        local_log "backup folder $MAILS (id=$NR) to $TARGET"

	create_folder_ifneeded "$HOST/$NAME.$NR"

	local ACTUAL_LINK="$BKP/$HOST/current_$NAME"
	if [ -e $ACTUAL_LINK ]; then
		local ACTUAL_LINK_DEST=$(readlink $ACTUAL_LINK)
		local_log "latest version is $ACTUAL_LINK => $ACTUAL_LINK_DEST"
		if [ $ACTUAL_LINK_DEST == $TARGET ]; then
			local_log "not using link-dest as this points to same version as we want to update"
		else
			local DEST_DIR="--link-dest=$ACTUAL_LINK_DEST"
			local_log "using destdir: $DEST_DIR"
		fi
	else
		local_log "file does not exist: $ACTUAL_LINK"
	fi

	local PWD=$(pwd)
	execute "cd $BKP/$HOST" 0
        execute "rsync -avuz $PARAMS $DEST_DIR --delete --delete-excluded $CONSTR:$MAILS/ $TARGET/" 0
	execute "cd $PWD" 0

	recreate_link $ACTUAL_LINK $TARGET
}

