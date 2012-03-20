#!/bin/bash

function local_log {
	echo "`date`: $1"
}

function execute {
	COMMAND=$1
	EXPECTED=$2
	local_log "executing: $COMMAND"
	if [ "$DEBUG" == 'debug' ]; then
		local_log "skipped as we are debugging"
	else
		`$COMMAND >> $LOG 2>> $ERR`
		RES=$?
		if [ $RES -ne $EXPECTED ]; then
			echo "command gave result $RES - expected $EXPECTED"
			exit 1
		fi
	fi
}

function execute_out {
        COMMAND=$1
	OUTPUT=$2
        EXPECTED=$3
        local_log "executing: $COMMAND and writing output to $OUTPUT"
	if [ "$DEBUG" == 'debug' ]; then
		local_log "skipped as we are debugging"
	else
	        `$COMMAND > $OUTPUT 2>> $ERR`
	        RES=$?
        	if [ $RES -ne $EXPECTED ]; then
                	echo "command gave result $RES - expected $EXPECTED"
	                exit 1
        	fi
	fi
}

function backup_database_pg { # db-name, username, subfolder - use .pgpass
	DB=$1
	USERNAME=$2
	SUBFOLDER=$3

	TARGET="$BKP/$SUBFOLDER/${DB}.sql.`date +%d`"
	LINK="$BKP/$SUBFOLDER/current_${DB}.gz"

	local_log "dumping pg database $DB to $TARGET as user $USERNAME"
	execute_out "$PGDUMP -U $USERNAME -w $DB" $TARGET 0
	execute "rm -f ${TARGET}.gz" 0
	execute "gzip $TARGET" 0

	local_log "recreating current link $LINK"
	execute "rm -f $LINK" 0
	execute "ln -s ${TARGET}.gz $LINK" 0

	local_log "$DB backup done"
}

function backup_database_mysql {
        DB=$1
        USERNAME=$2
        PASSWORD=$3
        SUBFOLDER=$4

        TARGET="$BKP/$SUBFOLDER/${DB}.sql.`date +%d`"
        LINK="$BKP/$SUBFOLDER/current_${DB}.gz"

        local_log "dumping mysql database $DB to $TARGET as user $USERNAME"
        execute_out "$MYDUMP -u$USERNAME -p$PASSWORD $DB" $TARGET 0
	execute "rm -f ${TARGET}.gz" 0
	execute "gzip $TARGET" 0
	local_log "dumped to $TARGET"

        local_log "recreating current link $LINK"
        execute "rm -f $LINK" 0
        execute "ln -s ${TARGET}.gz $LINK" 0

        local_log "$DB backup done"
}

function backup_folder { # folder to backup, name of the backup, special params
	NAME=$1
	FOLDER=$2
	PARAMS=$3

	TARGET="$BKP/${NAME}.`date +%d`"
	LINK="$BKP/current_$NAME"

	local_log "updating local copy from $FOLDER to $BKP/$NAME"
	execute "$RSYNC -avu $PARAMS --delete --delete-excluded $FOLDER $BKP/$NAME/" 0

	local_log "recreating folder $TARGET"
	execute "rm -rf $TARGET" 0
	execute "cp -al $BKP/$NAME $TARGET" 0
	
	local_log "recreating current link $LINK"
	execute "rm -f $LINK" 0
	execute "ln -s $TARGET $LINK" 0
	
	local_log "backup folder $NAME done"
}

function empty_folder {
	FOLDER=$1
	PATTERN=$2
	local_log "deleting all $PATTERN in $FOLDER"
	execute "find $FOLDER -name $PATTERN -exec rm -rf {} \;"
}

function sync2remote {
	PASSFILE=$1
	SOURCE=$2
	TARGET=$3
	PARAMS=$4
	local_log "syncing $SOURCE to $TARGET"
	execute "$RSYNC -avuz $PARAMS --delete --delete-excluded --password-file=$PASSFILE $SOURCE $TARGET" 0
	local_log "sync of $SOURCE done"
}

function tar_target {
        SRC="$BKP/$1"
        TARGET="$2/$1.tgz"

        OLDDIR=`pwd`
        execute "cd $BKP" 0

        local_log "taring $SRC to $TARGET"
        execute "rm -f $TARGET" 0
        execute "tar -czf $TARGET $SRC" 0
	local_log "$TARGET created"

        execute "cd $OLDDIR" 0

        local_log "taring $SRC done"
}

function cleanup_last_month {
	MONTH=`date +%m`
	if [ `date +%d` -ne 1 ]; then
		local_log "Only starting cleanup on first day of month"
		return
	fi

	local_log "Cleaning up last month - actual $MONTH"

	DATA[1]="" #dez=31
	DATA[2]="" #jan=31
	if [ $MONTH -eq 3 ]; then #feb=28
		YEAR=`date +%Y`
		LEAP=`expr $YEAR % 4`
		local_log "check for leap year (0=true): $LEAP"
		if [ $LEAP -eq 0 ]; then
			local_log "we have a leap year"
			DATA[3]="30 31"
		else
			local_log "no leap year"
			DATA[3]="29 30 31"
		fi
	fi
	DATA[4]="" #mar=31
	DATA[5]="31" #apr=30
	DATA[6]="" #mai=31
	DATA[7]="31" #jun=30
	DATA[8]="" #jul=31
	DATA[9]="" #aug=31
	DATA[10]="31" #sep=30
	DATA[11]="" #oct=31
	DATA[12]="31" #nov=30

	TOCLEAN=${DATA[$MONTH]}
	local_log "days from last month to remove: $TOCLEAN"
	for day in $TOCLEAN; do
		if [ $# -lt 1 ]; then
			local_log "WARNING: no folders given for cleanup"
			return
		else
			for arg in $*; do
				FILE=$BKP/${arg/\%DAY\%/$day}
				local_log "cleanup day $day with pattern $arg => $FILE"
				execute "rm -rf $FILE" 0
			done
		fi
	done
}
