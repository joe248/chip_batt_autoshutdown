#!/bin/bash

# Forked https://github.com/xtacocorex/chip_batt_autoshutdown
# Modified to shutdown on microUSB unplug with code from
# https://bbs.nextthing.co/t/updated-battery-sh-dumps-limits-input-statuses/2921
# Service code from noimjosh https://github.com/noimjosh/chip_autoshutdown/
# MIT LICENSE, SEE LICENSE FILE

# LOGGING HAT-TIP TO http://urbanautomaton.com/blog/2014/09/09/redirecting-bash-script-output-to-syslog/

# SIMPLE SCRIPT TO POWER DOWN THE CHIP BASED UPON BATTERY VOLTAGE

# THIS SCRIPT NEEDS TO BE RUN AS ROOT TO WORK

# CHANGE THESE TO CUSTOMIZE THE SCRIPT
# ****************************
# ** THESE MUST BE INTEGERS **
MINBATTERYPERCENTAGE=25
MINCHARGECURRENT=10
POLLING_WAIT=30

# ****************************

readonly SCRIPT_NAME=$(basename $0)
LAST_MESSAGE=""

log() {
    # echo "`date -u`" "$@"
    if [ "$@" != "$LAST_MESSAGE" ]; then
        LAST_MESSAGE="$@"
        logger -p user.notice -t "battery" "$@"
    fi
}

# TALK TO THE POWER MANAGEMENT
/usr/sbin/i2cset -y -f 0 0x34 0x82 0xC3



while true
do
    # GET POWER OP MODE
    POWER_OP_MODE=$(/usr/sbin/i2cget -y -f 0 0x34 0x01)

    # SEE IF BATTERY EXISTS
    BAT_EXIST=$(($(($POWER_OP_MODE&0x20))/32))
    if [ $BAT_EXIST == 1 ]; then
        
        # log "CHIP HAS A BATTERY ATTACHED"
        BAT_VOLT_MSB=$(/usr/sbin/i2cget -y -f 0 0x34 0x78)
        BAT_VOLT_LSB=$(/usr/sbin/i2cget -y -f 0 0x34 0x79)
        BAT_BIN=$(( $(($BAT_VOLT_MSB << 4)) | $(($(($BAT_VOLT_LSB & 0x0F)) )) ))
        BAT_VOLT_FLOAT=$(echo "($BAT_BIN*1.1)"|bc)
        # CONVERT TO AN INTEGER
        BAT_VOLT=${BAT_VOLT_FLOAT%.*}
    
	#read fuel gauge B9h
	BAT_GAUGE_HEX=$(i2cget -y -f 0 0x34 0xb9)
	# bash math -- converts hex to decimal so `bc` won't complain later...
	# MSB is 8 bits, LSB is lower 4 bits
	BAT_GAUGE_DEC=$(($BAT_GAUGE_HEX))
	# log "BATTERY PERCENTAGE IS $BAT_GAUGE_DEC %"

        # CHECK BATTERY PERCENTAGE AGAINST MINBATTERYPERCENTAGE
        if [ $BAT_GAUGE_DEC -le $MINBATTERYPERCENTAGE ]; then
            log "CHIP BATTERY PERCENTAGE $BAT_GAUGE_DEC% IS LESS THAN $MINBATTERYPERCENTAGE%"
            # log "CHECKING FOR CHIP BATTERY CHARGING"
            # GET THE CHARGE CURRENT
            BAT_ICHG_MSB=$(/usr/sbin/i2cget -y -f 0 0x34 0x7A)
            BAT_ICHG_LSB=$(/usr/sbin/i2cget -y -f 0 0x34 0x7B)
            BAT_ICHG_BIN=$(( $(($BAT_ICHG_MSB << 4)) | $(($(($BAT_ICHG_LSB & 0x0F)) )) ))
            BAT_ICHG_FLOAT=$(echo "($BAT_ICHG_BIN*0.5)"|bc)
            # CONVERT TO AN INTEGER
            BAT_ICHG=${BAT_ICHG_FLOAT%.*}
        
            # IF CHARGE CURRENT IS LESS THAN MINCHARGECURRENT, WE NEED TO SHUTDOWN
            if [ $BAT_ICHG -le $MINCHARGECURRENT ]; then
                log "CHIP BATTERY IS NOT CHARGING, SHUTTING DOWN NOW"
                shutdown -h now
            else
                log "CHIP BATTERY IS CHARGING"
            fi
        else
            #read Power OPERATING MODE register @01h
            POWER_OP_MODE=$(i2cget -y -f 0 0x34 0x01)
            #echo $POWER_OP_MODE

            CHARG_IND=$(($(($POWER_OP_MODE&0x40))/64))  # divide by 64 is like shifting rigth 6 times
            if [ $CHARG_IND -eq 1 ]; then
                log "BATTERY IS CHARGING ($BAT_GAUGE_DEC%)"
            else
                BAT_IDISCHG_MSB=$(i2cget -y -f 0 0x34 0x7C)
                BAT_IDISCHG_LSB=$(i2cget -y -f 0 0x34 0x7D)
                BAT_IDISCHG_BIN=$(( $(($BAT_IDISCHG_MSB << 5)) | $(($(($BAT_IDISCHG_LSB & 0x1F)) )) ))
                BAT_IDISCHG=$(echo "($BAT_IDISCHG_BIN)"|bc)
                if [ $BAT_IDISCHG -le $MINCHARGECURRENT ]; then
                    log "BATTERY IS CHARGED"
                else
                    log "BATTERY DISCHARGING ($BAT_GAUGE_DEC%)"
                fi 
            fi
            # log "CHIP BATTERY LEVEL IS GOOD"
        fi
    else
        log "BATTERY NOT PRESENT."
    fi
    sleep $POLLING_WAIT
done
