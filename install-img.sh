#!/bin/bash

# http://elinux.org/RPi_Easy_SD_Card_Setup#Flashing_the_SD_card_using_Mac_OSX

diskutil list


echo "Identify SD Card (e.g disk2, not disk2s1)"
read OF

OUTPUT=/dev/$OF

diskutil unmountDisk $OUTPUT
echo "Writing on $OUTPUT"
sudo dd bs=1m if=$1 of=$OUTPUT
