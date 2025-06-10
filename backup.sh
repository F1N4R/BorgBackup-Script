#!/bin/bash

# Variablen
REPO="ssh://meineREPO:borg-repo"
SOURCE="Pfad/Zur/Quelle"
EXCLUDES="Pfad/zum/Script/excludes.txt"
PASSPHRASE="MeineSuperSicherePassphrase"
LOGFILE="Pfad/zum/Script/backup.log"
DATE=$(date +'%Y-%m-%d_%H-%M')
EMAIL="recipient@example.org"

#Umgebungsvariable
export BORG_PASSPHRASE="$PASSPHRASE"

echo "### Starte Backup: $DATE" >> "$LOGFILE"

# Backup durchführen
borg create \
  --verbose --filter AME --stats --show-rc \
  --compression lz4 \
  --exclude-from "$EXCLUDES" \
  "$REPO"::BACKUP-"$DATE" \
  $SOURCE >> "$LOGFILE" 2>&1

BACKUP_EXIT=$?

# Alte Backups aufräumen (Prune)
borg prune \
  --list "$REPO" \
  --keep-daily=7 --keep-weekly=4 --keep-monthly=6 \
  >> "$LOGFILE" 2>&1

PRUNE_EXIT=$?

# Exit Code auswertung & E-Mail versand
GLOBAL_EXIT=$(( BACKUP_EXIT > PRUNE_EXIT ? BACKUP_EXIT : PRUNE_EXIT ))

if [ $GLOBAL_EXIT -eq 0 ]; then
    echo "Backup erfolgreich: $DATE" >> "$LOGFILE"

    SUBJECT="Backup Ergebnis: Erfolgreich (Exit-Code: $GLOBAL_EXIT) von $DATE"
    BODY="Das Backup wurde erfolgreich abgeschlossen: (Exit-Code: $GLOBAL_EXIT).\n\nLog-Auszug:\n$(grep -n "### Starte Backup: $DATE" $LOGFILE| cut -d: -f1 | xargs -I{} tail -n +{} $LOGFILE)"
    echo -e "$BODY" | mailx -s "$SUBJECT" "$EMAIL"
elif [ $GLOBAL_EXIT -eq 1 ]; then
    echo "Backup abgeschlossen mit Warnungen: $DATE" >> "$LOGFILE"

    SUBJECT="Backup Ergebnis: Erfolgreich mit Warnungen (Exit-Code: $GLOBAL_EXIT) von $DATE"
    BODY="Das Backup wurde erfolgreich abgeschlossen mit Warnungen: (Exit-Code: $GLOBAL_EXIT).\n\nLog-Auszug:\n$(grep -n "### Starte Backup: $DATE" $LOGFILE| cut -d: -f1 | xargs -I{} tail -n +{} $LOGFILE)"
    echo -e "$BODY" | mailx -s "$SUBJECT" "$EMAIL"
else
    echo "Fehler beim Backup: $DATE" >> "$LOGFILE"

    SUBJECT="Backup Ergebnis: Fehlerhaft (Exit-Code: $GLOBAL_EXIT) von $DATE"
    BODY="Das Backup wurde nicht abgeschlossen (unbekannter Fehler): (Exit-Code: $GLOBAL_EXIT).\n\nLog-Auszug:\n$(grep -n "### Starte Backup: $DATE" $LOGFILE| cut -d: -f1 | xargs -I{} tail -n +{} $LOGFILE)"
    echo -e "$BODY" | mailx -s "$SUBJECT" "$EMAIL"
fi

exit $GLOBAL_EXIT
