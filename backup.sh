#!/bin/bash

#####################################################################
# global configuration defaults overridden by /etc/backup.conf
#####################################################################

echo "loading defaults from $0"
DEBUG=$1

BKP=/home/backup
LOG=$BKP/backup_log.out
ERR=$BKP/backup_log.err

PGDUMP=/usr/bin/pg_dump
MYDUMP=/usr/bin/mysqldump
RSYNC=/usr/bin/rsync

CONFIG="/etc/backup.conf"

# allow to override defaults
echo "loading config from $CONFIG"
source $CONFIG
echo "loaded $CONFIG"

FUNCTIONS="$BKP/backup_functions.sh"
LOCALSCR="$BKP/backup_local.sh"

if [ "$DEBUG" == 'debug' ]; then
	echo "############################################"
	echo "# Config after loading $CONFIG"
	echo "############################################"
	echo "# BKP: $BKP"
	echo "# LOG: $LOG"
	echo "# ERR: $ERR"
	echo "# PGDUMP: $PGDUMP"
	echo "# MYDUMP: $MYDUMP"
	echo "# RSYNC: $RSYNC"
	echo "#"
	echo "# FUNCTIONS: $FUNCTIONS"
	echo "# LOCALSCR: $LOCALSCR"
	echo "############################################"
	exit 1
fi

# load functions
echo "loading functions from $FUNCTIONS"
source $FUNCTIONS
local_log "loaded $FUNCTIONS"

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
#sync2remote /etc/backup.pass /home/backup/etc/ "user@remote:./etc/"
######### SAMPLE backup_local.sh END #########

local_log 'done'
exit 0

