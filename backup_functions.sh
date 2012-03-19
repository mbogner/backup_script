#!/bin/bash

function local_log {
	echo "`date`: $1"
}

function execute {
	COMMAND=$1
	EXPECTED=$2
	local_log "executing: $COMMAND"
	`$COMMAND >> $LOG 2>> $ERR`
	RES=$?
	if [ $RES -ne $EXPECTED ]; then
		echo "command gave result $RES - expected $EXPECTED"
		exit 1
	fi
}

function execute_out {
        COMMAND=$1
	OUTPUT=$2
        EXPECTED=$3
        local_log "executing: $COMMAND and writing output to $OUTPUT"
        `$COMMAND > $OUTPUT 2>> $ERR`
        RES=$?
        if [ $RES -ne $EXPECTED ]; then
                echo "command gave result $RES - expected $EXPECTED"
                exit 1
        fi
}

function backup_database_pg { # db-name, username - use .pgpass
	DB=$1
	USERNAME=$2

	TARGET="$BKP/${DB}.sql.`date +%d`"
	LINK="$BKP/current_${DB}.gz"

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

        execute "cd $OLDDIR"

        local_log "taring $SRC done"
}
