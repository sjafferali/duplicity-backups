#!/bin/bash

source /opt/smods/dupbackup/.secret

##
DUPLICITY="/bin/duplicity"
ENCRYPT_KEY="616F6981"
CONTAINER=$(uname -n)
BACKUP_PATH="/"
RESTORE_PATH="/opt/smods/dupbackup/restoredir"
EXCLUDE="--exclude /proc --exclude /dev --exclude /sys --exclude /tmp --exclude /run --exclude /mnt --exclude /media --exclude /lost+found --exclude /var/mysqltmp --exclude /var/tmp"
FULL_LOG_FILE="/opt/smods/dupbackup/logs/full_log"
SUMM_LOG_FILE="/opt/smods/dupbackup/logs/summ_log"
LAST_FULL="/opt/smods/dupbackup/logs/last_full"
LAST_INC="/opt/smods/dupbackup/logs/last_inc"
LAST_BACKUP="/opt/smods/dupbackup/logs/last_backup"
PID=$$

restore_path() {
DIR=$(date +%m-%d-%Y_%T)

if [[ ! -z $1 ]]
then
        echo $(date +"%D %r")" ($PID) - Restore $1 to $RESTORE_PATH/$DIR/ from $TIME" >> $SUMM_LOG_FILE ;
        echo $(date +"%D %r")" ($PID) - Restore $1 to $RESTORE_PATH/$DIR/ from $TIME" >> $FULL_LOG_FILE ;
        $DUPLICITY --log-file $FULL_LOG_FILE --allow-source-mismatch restore --verbosity i --time $TIME --file-to-restore $1 --encrypt-key $ENCRYPT_KEY cf+http://$CONTAINER $RESTORE_PATH/$DIR/
        echo $(date +"%D %r")" ($PID) - Restored $1 to $RESTORE_PATH/$DIR/ from $TIME" >> $SUMM_LOG_FILE ;
        echo $(date +"%D %r")" ($PID) - Restored $1 to $RESTORE_PATH/$DIR/ from $TIME" >> $FULL_LOG_FILE ;
else
        echo $(date +"%D %r")" ($PID) Restore $1 to $RESTORE_PATH/$DIR/ from $TIME" >> $SUMM_LOG_FILE ;
        echo $(date +"%D %r")" ($PID) Restore $1 to $RESTORE_PATH/$DIR/ from $TIME" >> $FULL_LOG_FILE ;
        $DUPLICITY --log-file $FULL_LOG_FILE --allow-source-mismatch restore --verbosity i --time $TIME --encrypt-key $ENCRYPT_KEY cf+http://$CONTAINER $RESTORE_PATH/$DIR/
        echo $(date +"%D %r")" ($PID) - Restored $1 to $RESTORE_PATH/$DIR/ from $TIME" >> $SUMM_LOG_FILE ;
        echo $(date +"%D %r")" ($PID) - Restored $1 to $RESTORE_PATH/$DIR/ from $TIME" >> $FULL_LOG_FILE ;
fi
echo
echo "Restore Path: $RESTORE_PATH/$DIR/"
echo
}


show_help(){
echo '
Usage: buptool.sh [options] [function] (arg1) (arg2)

Functions
-----------------------------------------
help:           Shows this output.
backup:         Creates a full backup, or incremental if last full backup was less than 7 days ago.
full:           Creates a full backup.
inc:            Creates an incremental backup.
list:           List current backup chains.
files:          List files included in backup.
delete:         Removes all backups older than 28 days. The day can be overrided using the -t flag. Note that the -d will be
                needed to delete the files instead of just listing them
clean:          Runs a clean operation to cleanup previous backup errors. Note that the -d will be
                needed to delete the files instead of just listing them.
restore [file]: Performs a restore. File is optional argument that should be a relative path found by the files function.

Options
-----------------------------------------
-v:             Show verbose output.
-t [DATE/TIME]: Specify time of backup to use.
-d:             This option is required for the deletion when using the delete or clean commands.
'

}

ulimit -n 1024
VERSION=0.1
DELETE=""
TIME="now"
while getopts t:vd flag; do
        case $flag in
        t)
                TIME=$OPTARG ;
                ;;
        d)
                DELETE="--force" ;
                ;;
        v)
                VERBOSE=1 ;
                ;;
        ?)
                exit;
                ;;
        esac
done

shift $(( OPTIND - 1 ));

log_to_file() {
	if [[ $1 -eq 1 ]]
	then
		echo $(date +"%D %r")" ($PID) - Backup started" >> $SUMM_LOG_FILE ;
		echo $(date +"%D %r")" ($PID) - Backup started" >> $FULL_LOG_FILE ;
	else
		LAST_LINE=$($DUPLICITY collection-status --allow-source-mismatch --time $TIME --encrypt-key $ENCRYPT_KEY cf+http://$CONTAINER 2> /dev/null | egrep "Incremental|Full" | tail -1)
		LAST_BACKUP_DATE=$(echo $LAST_LINE | awk '{print$3" "$4" "$5" "$6}')
		LAST_BACKUP_TYPE=$(echo $LAST_LINE | awk '{print$1}')
		echo $(date +"%D %r")" ($PID) - $LAST_BACKUP_TYPE backup completed" >> $SUMM_LOG_FILE ;
		echo $(date +"%D %r")" ($PID) - $LAST_BACKUP_TYPE backup completed" >> $FULL_LOG_FILE ;
		date -d"$LAST_BACKUP_DATE" +%s > $LAST_BACKUP
		if [[ $LAST_BACKUP_TYPE == "Incremental" ]]
		then
			date -d"$LAST_BACKUP_DATE" +%s > $LAST_INC
		else
			date -d"$LAST_BACKUP_DATE" +%s > $LAST_FULL
		fi
	fi
}


case $1 in
help)
        show_help ;;
delete)
        if [[ -z $TIME ]]
        then
                TIME="28D"
        fi
        $DUPLICITY --allow-source-mismatch remove-older-than $TIME cf+http://$CONTAINER $DELETE ;;
clean)
        $DUPLICITY $DELETE --allow-source-mismatch cleanup cf+http://$CONTAINER ;;
restore)
        restore_path $2 ;;
backup)
	log_to_file 1 ;
        options="--log-file $FULL_LOG_FILE --allow-source-mismatch --full-if-older-than 14D --asynchronous-upload --volsize 250 $EXCLUDE --exclude-other-filesystems --encrypt-key $ENCRYPT_KEY" ;
        $DUPLICITY $options --verbosity i $BACKUP_PATH cf+http://$CONTAINER ;
	log_to_file 0 ;;
full)
	log_to_file 1 ;
        options="--allow-source-mismatch --asynchronous-upload --volsize 250 $EXCLUDE --exclude-other-filesystems --encrypt-key $ENCRYPT_KEY" ;
        $DUPLICITY full $options --verbosity i $BACKUP_PATH cf+http://$CONTAINER ;
	log_to_file 0 ;;
inc)
	log_to_file 1 ; 
        options="--allow-source-mismatch --asynchronous-upload --volsize 250 $EXCLUDE --exclude-other-filesystems --encrypt-key $ENCRYPT_KEY" ;
        $DUPLICITY incremental $options --verbosity i $BACKUP_PATH cf+http://$CONTAINER ;
	log_to_file 0 ;;
list)
        $DUPLICITY collection-status --allow-source-mismatch --time $TIME --encrypt-key $ENCRYPT_KEY cf+http://$CONTAINER ;;
files)
        $DUPLICITY list-current-files --allow-source-mismatch --time $TIME --encrypt-key $ENCRYPT_KEY cf+http://$CONTAINER ;;
*)
        show_help ;;
esac

unset PASSPHRASE
unset CLOUDFILES_APIKEY
