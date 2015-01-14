#!/bin/bash

BACKUP_DIR=./backup/
SCRIPT_DIR=./scripts/


PA_DAEMON_DIR=/etc/pulse/
PA_DAEMON_FILE=daemon.conf
PA_DAEMON_PATH=$PA_DAEMON_DIR$PA_DAEMON_FILE

BT_AUDIO_DIR=/etc/bluetooth/
BT_AUDIO_FILE=audio.conf
BT_AUDIO_PATH=$BT_AUDIO_DIR$BT_AUDIO_FILE

RULES_DIR=/etc/udev/rules.d/
RULES_FILE=99-input.rules
RULES_PATH=$RULES_DIR$RULES_FILE

UDEV_DIR=/usr/lib/udev/
UDEV_FILE=bluetooth
UDEV_PATH=$UDEV_DIR$UDEV_FILE
UDEV_SCRIPT=udev-bluetooth

BT_AGENT_DIR=/etc/init.d/
BT_AGENT_FILE=bluetooth-agent
BT_AGENT_PATH=$BT_AGENT_DIR$BT_AGENT_FILE
BT_AGENT_SCRIPT=bluetooth-agent

AUTOLOGIN_DIR=/etc/
AUTOLOGIN_FILE=inittab
AUTOLOGIN_PATH=$AUTOLOGIN_DIR$AUTOLOGIN_FILE

PA_CONF_DIR=/etc/default/
PA_CONF_FILE=pulseaudio
PA_CONF_PATH=$PA_CONF_DIR$PA_CONF_FILE

PA_CLIENT_DIR=/etc/pulse/
PA_CLIENT_FILE=client.conf
PA_CLIENT_PATH=$PA_CLIENT_DIR$PA_CLIENT_FILE

DBUS_PA_DIR=/etc/dbus-1/system.d/
DBUS_PA_FILE=pulseaudio-system.conf
DBUS_PA_PATH=$DBUS_PA_DIR$DBUS_PA_FILE

function backup {
    mkdir -p $BACKUP_DIR

    cp $PA_DAEMON_PATH $BACKUP_DIR$PA_DAEMON_FILE
    cp $BT_AUDIO_PATH $BACKUP_DIR$BT_AUDIO_FILE
    cp $RULES_PATH $BACKUP_DIR$RULES_FILE
    cp $AUTOLOGIN_PATH $BACKUP_DIR$AUTOLOGIN_FILE
    cp $PA_CONF_PATH $BACKUP_DIR$PA_CONF_FILE
    cp $PA_CLIENT_PATH $BACKUP_DIR$PA_CLIENT_FILE
    cp $DBUS_PA_PATH $BACKUP_DIR$DBUS_PA_FILE
}

function restore {
    cp $BACKUP_DIR$PA_DAEMON_FILE $PA_DAEMON_PATH
    cp $BACKUP_DIR$BT_AUDIO_FILE $BT_AUDIO_PATH
    cp $BACKUP_DIR$RULES_FILE $RULES_PATH
    cp $BACKUP_DIR$AUTOLOGIN_FILE $AUTOLOGIN_PATH
    cp $BACKUP_DIR$PA_CONF_FILE $PA_CONF_PATH
    cp $BACKUP_DIR$PA_CLIENT_FILE $PA_CLIENT_PATH
    cp $BACKUP_DIR$DBUS_PA_FILE $DBUS_PA_PATH

    rm $UDEV_PATH
    rm $BT_AGENT_PATH
}

function init {
    apt-get update
    apt-get upgrade
    apt-get install bluez pulseaudio-module-bluetooth python-gobject python-gobject-2
}

function install {



    # update bluetooth audio settings
    sed -i -e 's/\[General\]/\[General\]\nEnable=Source,Sink,Media,Socket/g' $BT_AUDIO_PATH

    # TODO deal with bluetooth mac device + trusted

    # add a rule when a device connects
    echo "KERNEL==\"input[0-9]*\", RUN+=\"/usr/lib/udev/bluetooth\"" >> $RULES_PATH

    # create the script that will be executed when the rules is run
    mkdir -p $UDEV_DIR
    cp $SCRIPT_DIR$UDEV_SCRIPT $UDEV_PATH
    chmod 774 $UDEV_PATH

    # create a service to watch for new bluetooth connection
    cp $SCRIPT_DIR$BT_AGENT_SCRIPT $BT_AGENT_PATH
    chmod 755 $BT_AGENT_PATH
    update-rc.d $BT_AGENT_FILE defaults

    # activate autologin
    sed -i -e 's/1:2345:respawn:\/sbin\/getty .* tty1/1:2345:respawn:\/bin\/login -f pi tty1 <\/dev\/tty1 >\/dev\/tty1 2>\&1/g' $AUTOLOGIN_PATH

    # change the default audio output to headphone jack (HDMI by default)
    su pi -c "amixer cset numid=3 1"
    # turn up the volume
    su pi -c "amixer set Master 100%"
    su pi -c "pacmd set-sink-volume 0 65537"

    # configure pulseaudio in system-mode
    sed -i -e 's/PULSEAUDIO_SYSTEM_START=0/PULSEAUDIO_SYSTEM_START=1/g' $PA_CONF_PATH
    sed -i -e 's/DISALLOW_MODULE_LOADING=1/DISALLOW_MODULE_LOADING=0/g' $PA_CONF_PATH

    adduser pi pulse-access

    sed -i -e 's/; autospawn = no/autospawn = no/g' $PA_CLIENT_PATH

    sed -i -e 's/; exit-idle-time = 20/exit-idle-time = -1/g' $PA_DAEMON_PATH
    sed -i -e 's/; resample-method = speex-float-3/resample-method = trivial/g' $PA_DAEMON_PATH
    sed -i -e 's/; allow-module-loading = yes/allow-module-loading = yes/g' $PA_DAEMON_PATH
    sed -i -e 's/; load-default-script-file = yes/load-default-script-file = yes/g' $PA_DAEMON_PATH
    sed -i -e 's/; default-script-file/default-script-file/g' $PA_DAEMON_PATH

    sed -i -e 's/<allow own="org.pulseaudio.Server"\/>/<allow own="org.pulseaudio.Server"\/>\n    <allow send_destination="org.bluez"\/>\n    <allow send_interface="org.bluez.Manager"\/>\n/g' $DBUS_PA_PATH
}

case "$1" in
    init)
        init
        ;;

    install)
        install
        ;;
    backup)
        backup
        ;;
    restore)
        restore
        ;;
    *)
        echo $"Usage: $0 {install|backup|restore}"
        exit 1
esac
