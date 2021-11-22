#!/bin/bash
# Author: REDD
# Requires SSHPASS, OpenSSH, and coreutils-base64 also.

# Toggle Switches
#############################################
# 1 = ON
# 0 = OFF
#############################################


# Please set the HANDSHAKE_DIR to the correct Handshake folder.
HANDSHAKE_DIR="/root/hs"

# For AUTO_MODE to work, SSH/Email/DEST_DIR needs to be set correctly.
#   (RECOMMENDED: Run the script 1st before setting AUTO_MODE or ANY AUTO to 1. )
AUTO_MODE="0"
AUTO_OHC="0"
AUTO_SSH="0"

# OnlineHashCrack Settings
#############################################
# Turns on or off OHC Upload.
OHC="0"
# Email related to OHC account.
EMAIL=""


# SSH Credentials
#############################################
# SSH Username and Password.
# - If you want to input it in the script while it runs, credentials will be saved locally.
HOST="XXX.XXX.XXX.XXX"
USER=""
PASS=""
# Files to send to Remote Host.
FILES=$(find ${HANDSHAKE_DIR} -type f -name '*.pcap' -o -name '*.cap' -o -name '*.22000')
DEST_DIR="/Destination/Directory/Here"


#############################################
CONFIG_DIR="/root/.hstrans"
SETTING_FILE="${CONFIG_DIR}/setting.db"
TEMP_KEY="${CONFIG_DIR}/input.key"
USER_FILE="${CONFIG_DIR}/user.cfg"
OPTION_FILE="${CONFIG_DIR}/option.cfg"
#############################################

if [ ! -d "${CONFIG_DIR}" ]; then
        mkdir -p "${CONFIG_DIR}";
fi

function do_exit () {
        echo -e ""
        echo -e "Done."
        echo -e ""
        exit 0;
}

if [ "${HOST}" == "" ] || [ "${HOST}" == "XXX.XXX.XXX.XXX" ]; then
        echo -e "Please set the HOST Variable in the script and relaunch."
        exit 1;
fi

TOTAL_FILES=(`find ${HANDSHAKE_DIR} -maxdepth 1 -name "*.pcap" -o -name "*.cap" -o -name "*.22000"`)
if [ ${#TOTAL_FILES[@]} -eq 0 ]; then
        echo -e "There's no handshakes to transfer. Please capture some or set the correct directory."
        do_exit;
fi

if [ "${AUTO_SSH}" == "1" ]; then
        if [ ! -f "${SETTING_FILE}" ] && [ ! -f "${USER_FILE}" ]; then
                if [ "${USER}" == "" ] && [ "${PASS}" == "" ]; then
                        echo -e "Please set the SSH Variables or run first with AUTO_SSH off.";
                        do_exit;
                fi
        fi
fi

if [ "${AUTO_MODE}" == "1" ]; then
        STRING="Please make sure all variables needed for AUTO MODE are set."
        if [ "${HOST}" == "XXX.XXX.XXX.XXX" ] || [ "${HOST}" == "" ]; then
                echo -e "${STRING}"
                do_exit;
        fi
        if [ "${USER}" == "" ] || [ "${PASS}" == "" ]; then
                if [ ! -f "${SETTING_FILE}" ] || [ ! -f "${USER_FILE}" ]; then
                        echo -e "${STRING}"
                        do_exit;
                fi
        fi
        if [ "${EMAIL}" == "" ]; then
                echo -e "${STRING}"
                do_exit;
        fi
fi

function no_settings_file () {
        echo -e "Pushing files to ${HOST} with SSH USER - ${USER}."
        sshpass -p ${PASS} scp ${FILES} ${USER}@${HOST}:${DEST_DIR}
}

function settings_file () {
        if [ -f "${SETTING_FILE}" ]; then
                echo -e "Using locally saved credentials. Loading.."
                base64 --decode ${SETTING_FILE} > ${TEMP_KEY}
                PASS=$(cat ${TEMP_KEY} | base64 --decode)
                USER=$(cat ${USER_FILE})
                rm ${TEMP_KEY}
                echo -e "Pushing files to ${HOST} with SSH USER - ${USER}."
                sshpass -p ${PASS} scp ${FILES} ${USER}@${HOST}:${DEST_DIR}
        fi
}

function setup_settings_file () {
        echo -e "(All your data is saved LOCALLY.)"
        read -p "Enter your SSH Username: " INPUT_USER
        echo -e "${INPUT_USER}" > ${USER_FILE}
        echo -e "(Passwords are NOT saved in Plain Text Format.)"
        read -p "Enter your SSH Password: " INPUT_PASS
        echo -e "${INPUT_PASS}" | base64 > ${TEMP_KEY} && base64 ${TEMP_KEY} > ${SETTING_FILE}
        SHOW_ENC=$(cat ${SETTING_FILE})
        echo -e "  -> Encrypted input to: ${SHOW_ENC}"
        echo -e ""
        rm ${TEMP_KEY}
}

function auto_ohc () {
        if [ "${AUTO_OHC}" == "1" ]; then
                if [ "${EMAIL}" == "" ]; then
                        echo -e "No Email provided. Skipping.."
                        do_exit;
                fi
                for i in ${FILES}; do
                curl -X POST -F "email=${EMAIL}" -F "file=@/${i}" https://api.onlinehashcrack.com;
                echo "--> Successfully submitted ${i} to OnlineHashCrack.com API!";
                done
        elif [ "${AUTO_OHC}" == "0" ]; then
                read -p "What email address do you want to associate with Onlinehashcrack.com? " EMAIL
                for i in ${FILES}; do
                curl -X POST -F "email=${EMAIL}" -F "file=@/${i}" https://api.onlinehashcrack.com;
                echo "--> Successfully submitted ${i} to OnlineHashCrack.com API!";
                done
        fi
        do_exit
}

function do_confirm_ohc () {
        if [ "${AUTO_OHC}" == "1" ]; then
                auto_ohc;
        fi
        read -p "Do you want to upload handshake files to OnlineHashCrack.com? " CONFIRM
        case "$CONFIRM" in
        y|Y ) auto_ohc;;
        n|N ) do_exit;;
        * ) echo "Please choose Yes or No. (y/n)" && do_confirm_ohc;;
    esac
}


function run () {
        if [ ! -f "${OPTION_FILE}" ]; then
                echo -e "(If you have Credentials set in the Script Variables, Please select (N)o. )"
                echo -e " - This script will remember your answers."
                read -p "Do you want to save your SSH User/Password? (y/n) " OPTION
                case "$OPTION" in
                        y|Y ) echo -e "1" > ${OPTION_FILE} && setup_settings_file;;
                        n|N ) echo -e "0" > ${OPTION_FILE} && no_settings_file;;
                        * ) echo "Please choose Yes or No. (y/n) " && run;;
                esac
        fi
        if [ -f "${OPTION_FILE}" ]; then
                OPTION=$(cat ${OPTION_FILE})
                if [ "${OPTION}" == "0" ]; then
                        no_settings_file;
                        if [ "${OHC}" == "0" ]; then
                                do_exit;
                        else
                                do_confirm_ohc;
                        fi
                fi
                if [ "${OPTION}" == "1" ]; then
                        settings_file;
                        if [ "${OHC}" == "0" ]; then
                                do_exit;
                        else
                                do_confirm_ohc;
                        fi
                fi
        fi
}
run;
