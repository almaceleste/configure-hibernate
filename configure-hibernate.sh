#!/bin/bash

# configures the system to support hibernate
# GNU Affero GPL 3.0 (ɔ) 2020 almaceleste

readonly scriptname='configure-hibernate'
readonly version=0.1.1

readonly fstab='/etc/fstab'
readonly grub='/etc/default/grub'
readonly initramfs='/etc/initramfs-tools/conf.d/resume'
readonly logind='/etc/systemd/logind.conf'
readonly pattern='GRUB_CMDLINE_LINUX_DEFAULT=.*'
default='/etc/polkit-1/localauthority/50-local.d/org.freedesktop.hibernate.pkla'

function help(){
    read -r -d '' message << EOM
usage:  $scriptname.sh [options]
configures the system to support hibernate. asks sudo privileges to change system files.

all options may be absent. use it only if you know what you do and want to get some specific
result. if the option is absent, it will be calculated automatically.

options:
    --help              show this help and exit
    --unset-recordfail  (single option) create a service to unset grub recordfail and get the
                        grub boot menu will not appear on boot after hibernation. this option
                        is necessary only if your system is already configured for hibernation,
                        but you found out that the grub boot menu appear at boot time after
                        hibernation, and you want to disable it
    --polkit=path.pkla  path to the polkit .pkla file for configuration, e.g.
                        /etc/polkit-1/localauthority/50-local.d/org.freedesktop.hibernate.pkla
    --suffix=something  suffix for backup files. if absent, the datetime stamp will be used
    --swap=identifier   identifier of the swap partition, something like UUID=84a9...b17 or
                        /dev/nvme0n1p2
    --test              test your system for hibernation compatibility
    --version           show version info and exit

repo: <https://github.com/almaceleste/$scriptname>
EOM
    echo "$message"
}

function getswap(){
    echo $(cat $fstab | grep '^[^#].*swap' | awk '{printf $1}')
}

function testgrub(){
    echo $(cat $grub | sed --silent --regexp-extended "s/^${pattern}resume=([^ |\"]*).*/\1/p")
}

function test(){
    echo '┌──────────────────────────'
    echo '│ ⚠️ test option is not realized yet. coming the other day or earlier'$'\n'
}

function version(){
    read -r -d '' message << EOM
$scriptname v$version

Copyleft (ɔ) 2020 almaceleste
License: GNU Affero GPL 3.0 <https://gnu.org/licenses/agpl-3.0.html>.
This is free software: you are free to change and redistribute it under the same license.
There is NO WARRANTY, to the extent permitted by law.

Written by almaceleste.
EOM
    echo "$message"
}

function setgrub(){
    # check if grub is not configured to hibernate
    if [[ $swap != $(testgrub) ]]; then
        # check if grub already has resume entry
        if [ "$(testgrub)" ]; then
            # change already configured resume entry to the current swap
            echo 'change already configured resume entry to the current swap'
            sudo sed --in-place=.$suffix --regexp-extended "s/^($pattern resume=)[^ |\"]*(.*)/\1$swap\2/" $grub
            echo "$grub was changed. the old version was saved in $grub.$suffix"
        else
            # configure grub to resume the system for the current swap
            echo 'configure grub to resume the system for the current swap'
            sudo sed --in-place=.$suffix --regexp-extended "s/^($pattern)\"$/\1 resume=$swap\"/" $grub
            echo "$grub was changed. the old version was saved in $grub.$suffix"
        fi
        sudo update-grub
    else
        # grub is already configured properly
        echo 'grub is already configured properly'
    fi
}

function setinitramfs(){
    # check if initramfs is not configured yet properly
    if [ ! "$(cat $initramfs | grep --ignore-case "RESUME=$swap")" ]; then
        # check if the initramfs resume file exists
        if [ -f $initramfs ]; then
            # create a backup copy of initramfs if it exists
            sudo cp $initramfs $initramfs.$suffix
            echo "a backup copy of the $initramfs was created in $initramfs.$suffix"
        fi
        # create initramfs resume file
        echo RESUME=$swap | sudo tee $initramfs
        echo "$initramfs was configured to use current swap to resume"
    fi
    # update initramfs
    sudo update-initramfs -u
}

function setlidswitch(){
    # configure lid switch actions
    # ask if the user wants to configure hibernation by lid closing
    read -r -d '' prompt << EOM
┌──────────────────────────
│ ⚠️ do you want to hibernate the system by closing the lid? (yes/no)
EOM
    while true; do
        read -p "$prompt " answer
        case $answer in
            [Yy]* )
                echo "│ ⚠️ you answered '$answer'"
                lidhibernate=true
                break;;
            [Nn]* )
                echo "│ ⚠️ you answered '$answer'"
                break;;
            * )
                echo "│ ⚠️ you answered '$answer'. please answer yes or no."
                ;;
        esac
    done
    # configure logind.conf to hibernate by lid closing
    if [ $lidhibernate ]; then
        changed=''
        # create backup file for logind.conf
        sudo cp $logind $logind.$suffix
        # if lid switch action is not configured to hibernate (suspend by default)
        if [ ! "$(cat $logind | grep '^HandleLidSwitch=hibernate$')" ]; then
            # configure lid switch action to hibernate
            if [ ! "$(sudo sed --in-place --regexp-extended 's/^#?(HandleLidSwitch=).*$/\1hibernate/' $logind)" ]; then
                changed=true
            else
                echo "something very wrong with that $logind. you could write 'HandleLidSwitch=hibernate' in it yourself."
                break
            fi
        else
            # disable lid switch action
            if [ ! "$(sudo sed --in-place --regexp-extended 's/^#?(HandleLidSwitch=).*$/#\1suspend/' $logind)" ]; then
                changed=true
            else
                echo "something very wrong with that $logind. you could write '#HandleLidSwitch=suspend' in it yourself."
                break
            fi
        fi
        # ask if the user wants to prevent hibernation by lid closing while the computer is docked
        read -r -d '' prompt << EOM
┌──────────────────────────
│ ⚠️ do you want to prevent hibernation by the lid closing while the computer is docked? (yes/no)
EOM
        while true; do
            read -p "$prompt " answer
            case $answer in
                [Yy]* )
                    echo "│ ⚠️ you answered '$answer'"
                    liddocked=true
                    break;;
                [Nn]* )
                    echo "│ ⚠️ you answered '$answer'"
                    break;;
                * )
                    echo "│ ⚠️ you answered '$answer'. please answer yes or no."
                    ;;
            esac
        done
        if [ $liddocked ]; then
            # enable ignoring lid close while the computer is docked
            if [ ! "$(cat $logind | grep '^HandleLidSwitchDocked=ignore$')" ]; then
                if [ ! "$(sudo sed --in-place --regexp-extended 's/^#?(HandleLidSwitchDocked=).*$/\1ignore/' $logind)" ]; then
                    changed=true
                else
                    echo "something very wrong with that $logind. you could write 'HandleLidSwitchDocked=ignore' in it yourself."
                fi
            fi
        else
            # disable ignoring lid close while the computer is docked
            if [ ! "$(sudo sed --in-place --regexp-extended 's/^#?(HandleLidSwitchDocked=).*$/#\1ignore/' $logind)" ]; then
                changed=true
            fi
        fi
        if [ $changed ]; then
            echo "$logind was changed. the old version was saved in $logind.$suffix"
        else
            sudo rm $logind.$suffix
            echo "$logind is already configured"
        fi
    fi
}

function setpolicy(){
    # enable hibernate permissions by policy
    declare found=''
    # system paths for the local policykits
    declare -A polkitpaths
    polkitpaths['etc']='/etc/polkit-1/localauthority/50-local.d/'
    polkitpaths['var']='/var/lib/polkit-1/localauthority/50-local.d/'
    # search for the currently used policykits
    for polkitpath in ${polkitpaths[@]}; do
        # create list of the currently used policykits in the policykit folder
        polkits=$(sudo find $polkitpath -name *.pkla)
        # iterate list of the currently used policykits
        for polkit in $polkits; do
            unset entry changed policies
            declare -a entry policies
            # read prepared policy entries from policykit to string array (see done string below)
            while IFS=$'\n' read -d "|" -ra entry; do
                unset policy keys policystr
                declare -a keys
                declare -A policy
                # convert string array to associative array
                for i in ${!entry[@]}; do
                    IFS='=' read -r key value <<< ${entry[$i]}
                    policy+=([$key]=$value)
                    keys+=("$key")
                done
                # check if policy has hibernate permissions rule
                if [ "$(echo ${policy[Action]} | grep 'org.freedesktop.*.hibernate')" ]; then
                    if [ "$(echo ${policy[Identity]} | grep 'unix-user:\*')" ]; then
                        if [ ! "$(echo ${policy[ResultActive]} | grep 'yes')" ]; then
                            policy[ResultActive]='yes'
                            changed=true
                        fi
                        found=true
                    fi
                fi
                # create string contained policy entry
                policystr+="${keys[0]}"$'\n'
                for (( i=1; $i < ${#policy[@]}; i+=1 )); do
                    key="${keys[$i]}"
                    policystr+="$key=${policy[$key]}"$'\n'
                done
                policies+=("$policystr")
            # read policykit file and prepare it to read policy entries from it
            done <<< $(sudo awk 'BEGIN {RS=""; FS="\n"} {print $0; print "|"}' $polkit)
            if [ $changed ]; then
                # create backup of the policykit file
                sudo mv $polkit $polkit.$suffix
                # write previously saved policy entries to the file
                for item in "${policies[@]}"; do
                    echo "$item" | sudo tee --append $polkit
                done
                echo "policykit $polkit was changed. backup copy of it was created in $polkit.$suffix"
            fi
        done
    done
    # if policykit for hibernate permissions is not found
    if [ ! $found ]; then
        # create string for  hibernate permissions policy
        read -r -d '' policy << EOM
[Hibernate permissions for all users in upower]
Identity=unix-user:*
Action=org.freedesktop.upower.hibernate
ResultActive=yes

[Hibernate permissions for all users in logind]
Identity=unix-user:*
Action=org.freedesktop.login1.hibernate;org.freedesktop.login1.handle-hibernate-key;org.freedesktop.login1;org.freedesktop.login1.hibernate-multiple-sessions;org.freedesktop.login1.hibernate-ignore-inhibit
ResultActive=yes
EOM
        # write policy to the policykit file
        echo "$policy" | sudo tee $default
    fi
}

function setrecordfail(){
    # create a service to unset grub recordfail to get the grub boot menu will not appear on boot after hibernation
    # ask if the user wants to configure a service to unset recordfail
    read -r -d '' prompt << EOM
┌──────────────────────────
│ ⚠️ do you want to create a service that will unset grub recordfail option when the computer
│   goes into hibernate mode (this prevents the grub boot menu from appearing on boot after
│   hibernation)? (yes/no)
EOM
    while true; do
        read -p "$prompt " answer
        case $answer in
            [Yy]* )
                echo "│ ⚠️ you answered '$answer'"
                createservice=true
                break;;
            [Nn]* )
                echo "│ ⚠️ you answered '$answer'"
                break;;
            * )
                echo "│ ⚠️ you answered '$answer'. please answer yes or no."
                ;;
        esac
    done
    if [ $createservice ]; then
        # create service settings string
        read -r -d '' settings << EOM
[Unit]
Description=Unset recordfail in grubenv after hibernation.
After=hibernate.target

[Service]
Type=oneshot
ExecStart=/usr/bin/grub-editenv /boot/grub/grubenv unset recordfail

[Install]
WantedBy=hibernate.target hybrid-sleep.target
EOM
        # create service file
        echo "$settings" | sudo tee /etc/systemd/system/grub-unset-recordfail.service
        # enable service
        sudo systemctl start grub-unset-recordfail
        sudo systemctl enable grub-unset-recordfail
        sudo systemctl stop grub-unset-recordfail
    fi
}

function configurehibernate(){
    read -r -d '' prompt << EOM
┌──────────────────────────
│ ⚠️ hi. this program will configure your system for hibernation now. sudo password will be asked
│   for actions on system files. changed system files will be backuped up.
│   do want to continue? (yes/no)
EOM
    while true; do
        read -p "$prompt " answer
        case $answer in
            [Yy]* )
                echo "│ ⚠️ you answered '$answer'"
                echo "│   we will start now 🚀"
                break;;
            [Nn]* )
                echo "│ ⚠️ you answered '$answer'"
                echo "│   good bye 👋"
                exit;;
            * )
                echo "│ ⚠️ you answered '$answer'. please answer yes or no."
                ;;
        esac
    done

    setgrub
    setinitramfs
    setlidswitch
    setpolicy
    setrecordfail
    sudo systemctl restart systemd-logind.service

    echo '┌──────────────────────────'
    echo '│ ⚠️ all done. your system was configured for hibernation '$'\n'
    echo '│   good bye 👋'
    echo '│   and may the force of hibernation be with you '
}

# calculate some variables
suffix=$(date +%Y%m%d%H%M)
swap=$(getswap)

# parse arguments passed to the script
declare -A args
case $@ in
    '')
        configurehibernate
        exit;;
    *)
        for arg in "$@"; do
            IFS='=' read -r key value <<< $arg
            args+=([$key]=$value)
        done
        ;;
esac
for key in ${!args[@]}; do
    case $key in
        --help)
            help
            exit;;
        --polkit)
            default=${args[$key]}
            needrun=true
            ;;
        --suffix)
            suffix=${args[$key]}
            needrun=true
            ;;
        --swap)
            swap=${args[$key]}
            needrun=true
            ;;
        --test)
            test
            exit;;
        --unset-recordfail)
            setrecordfail
            exit;;
        --version)
            version
            exit;;
        *)
            echo "┌──────────────────────────"
            echo "│ ⚠️ $key is not a supported option"$'\n'
            help
            exit;;
    esac
done

if [ $needrun ]; then
    echo 'need run'
    configurehibernate
fi
