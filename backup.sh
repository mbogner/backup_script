#!/bin/bash

#####################################################################
# global configuration defaults overridden by /etc/backup.conf
#####################################################################

echo "loading defaults from $0"
DEBUG=$1

BKP=/home/backup
SCRIPTDIR=$BKP

PGDUMP=/usr/bin/pg_dump
MYDUMP=/usr/bin/mysqldump
RSYNC=/usr/bin/rsync

CONFIG="/etc/backup.conf"
OVERVIEW="/var/log/backup.log"

# allow to override defaults
echo "loading config from $CONFIG"
source $CONFIG
echo "loaded $CONFIG"

LOG=$BKP/backup_log.out
ERR=$BKP/backup_log.err
SUC=$BKP/backup_log.suc

FUNCTIONS="$SCRIPTDIR/backup_functions.sh"
LOCALSCR="$SCRIPTDIR/backup_local.sh"

if [ "$DEBUG" == 'debug' ]; then
	echo "############################################"
	echo "# Config after loading $CONFIG"
	echo "############################################"
	echo "# BKP: $BKP"
	echo "# SCRIPTDIR: $SCRIPTDIR"
	echo "# LOG: $LOG"
	echo "# ERR: $ERR"
	echo "# SUC: $SUC"
	echo "# PGDUMP: $PGDUMP"
	echo "# MYDUMP: $MYDUMP"
	echo "# RSYNC: $RSYNC"
	echo "#"
	echo "# FUNCTIONS: $FUNCTIONS"
	echo "# LOCALSCR: $LOCALSCR"
	echo "############################################"
fi

# load functions
echo "loading functions from $FUNCTIONS"
source $FUNCTIONS
local_log "loaded $FUNCTIONS"

local_log "started backup" >> $OVERVIEW

# execute local backup script
local_log "executing local script $LOCALSCR"
source $LOCALSCR
local_log "executed $LOCALSCR"

########### SAMPLE backup_local.sh ###########
#local_log "postgresql section"
#backup_database_pg dbname username
#
#local_log "mysql section"
#backup_database_mysql dbname user pass subfolder
#
#local_log "folder section"
#backup_folder home /home/ "--exclude=backup --exclude=lost+found"
#backup_folder home /home/
#
#local_log "sync section"
#sync2remote /etc/backup.pass $BKP/etc/ "user@remote:./etc/"
#
#cleanup_last_month dsubfolder/dbname.sql.%DAY%.gz home.%DAY%
######### SAMPLE backup_local.sh END #########

local_log 'done'
execute "touch $SUC" 0
local_log "successful" >> $OVERVIEW
exit 0

