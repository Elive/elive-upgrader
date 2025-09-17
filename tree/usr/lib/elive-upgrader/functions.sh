#!/bin/bash
#SOURCE="$0"
#source /usr/lib/elive-tools/functions
#el_make_environment
. gettext.sh
TEXTDOMAIN="elive-upgrader"
export TEXTDOMAIN

# get patreon status
if [[ -s /etc/elive/settings ]] ; then
    source /etc/elive/settings
fi

# distro version
case "$( cat /etc/debian_version )" in
    12.*|"bookworm"*)
        is_bookworm=1
        APTGET_OPTIONS="-o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confnew -y --allow-downgrades"
        hooks_d="/usr/lib/elive-upgrader/hooks-bookworm"
        ;;
    11.*|"bullseye"*)
        is_bullseye=1
        APTGET_OPTIONS="-o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confnew -y --allow-downgrades"
        hooks_d="/usr/lib/elive-upgrader/hooks-bullseye"
        ;;
    10.*|"buster"*)
        is_buster=1
        APTGET_OPTIONS="-o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confnew -y --allow-downgrades"
        hooks_d="/usr/lib/elive-upgrader/hooks-buster"
        ;;
    7.*|"wheezy"*)
        is_wheezy=1
        APTGET_OPTIONS="-o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confnew -y --force-yes"
        hooks_d="/usr/lib/elive-upgrader/hooks"
        ;;
    *)
        APTGET_OPTIONS="-o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confnew -y --allow-downgrades"
        hooks_d="/usr/lib/elive-upgrader/hooks"
        ;;
esac

show_help(){
    echo "Usage:
elive-upgrader                                  upgrades your system with everything needed
sudo elive-upgrader-root --update               update the tool itself
sudo elive-upgrader-root --upgrade              full upgrade of the system
sudo elive-upgrader-root --updates-available    show amount of available package updates
sudo elive-upgrader-root --upgrade-firmware     updates your BIOS firmware (if any found)
sudo elive-upgrader-root --fix                  fix a possible broken state of your packages
"
}

displaytime(){
  local T=$1
  local D=$((T/60/60/24))
  local H=$((T/60/60%24))
  local M=$((T/60%60))
  local S=$((T%60))
  (( $D > 0 )) && printf '%d days ' $D
  (( $H > 0 )) && printf '%d hours ' $H
  (( $M > 0 )) && printf '%d minutes ' $M
  (( $D > 0 || $H > 0 || $M > 0 )) && printf 'and '
  printf '%d and seconds\n' $S
}


notify_user_system_updated(){
    hour="$(date +%k)"
    if [[ "${hour}" -ge "21" ]] || [[ "$hour" -lt "8" ]] ; then
        el_explain 2 "ignoring reproduction of sound because we may be sleeping at this hour"
    else
        # play updated song
        if [[ -s "/usr/share/eliveinstaller/data/1up.wav" ]] ; then
            if [[ -x "$(which paplay)" ]] ; then
                paplay "/usr/share/eliveinstaller/data/1up.wav" &
            else
                if [[ -x "$(which aplay)" ]] ; then
                    aplay "/usr/share/eliveinstaller/data/1up.wav" &
                fi
            fi
        fi
    fi
    el_notify normal znes "Elive Updated" "$( eval_gettext "Your Elive has been updated with the latest fixes and features!" )" 2>/dev/null
}

upgrade_system_delayed(){
    local timestamp limit_time_seconds num_updates time_passed
    timestamp="$HOME/.config/elive-upgrader/timestamp-last-upgrade"
    if ! [[ -d "$( dirname "$timestamp" )" ]] ; then
        mkdir -p "$( dirname "$timestamp" )"
        touch "$timestamp"
    fi

    # TODO: change it to monthly
    #limit_time_seconds="2419200" # 27 days (4 weeks - 1 day)  # monthly is the best option for now, to not annoy much the user with popups and updates are not so important, so will have from time to time some yummy improvements (also not much suggestions of desktop upgrades, etc)
    limit_time_seconds="1209600" # 14 days
    #limit_time_seconds="604800" # one week
    #limit_time_seconds="518400" # 6 days
    #limit_time_seconds="6" # tests only!
    if [[ -e "$timestamp" ]] ; then
        time_passed="$( echo "$(date +%s) - $( stat -c %Y "$timestamp" )" | LC_ALL="$EL_LC_EN" bc -l | sed -e 's|\..*$||g' )"
    else
        touch "$timestamp"
        time_passed="999999999999999999999999999"
    fi

    if [[ "$time_passed" -gt "$limit_time_seconds" ]] ; then
        # get number of available updates
        num_updates="$( sudo elive-upgrader-root --updates-available )"
        el_debug "upgrades found: $num_updates"

        if [[ -n "$num_updates" ]] && [[ "$num_updates" -gt 0 ]] ; then
            # TODO: make this widget not-annoying (not popup in first page), use the trayer like elive-news
            if $guitool --question --text="${num_updates} $( eval_gettext "Updates available. Do you want to upgrade your system?" )" 1>/dev/null 2>&1 ; then

                $guitool --info --text="$( eval_gettext "Follow the terminal instructions when they appear, answering the questions. Verify that the upgrade won't remove any essential system packages." )" 1>/dev/null 2>&1
                # note: --noaptupdate because when we did --upgdates-available before we already updated the packages list
                sudo elive-upgrader-root --upgrade --noaptupdate

                # upgrade firmwares too if the user wanted to upgrade his system
                sudo elive-upgrader-root --upgrade-firmwares
            fi
        fi

        # always mark/park until the next month, we dont want to run apt-get update at every start
        touch "$timestamp"
    else
        el_debug "Not enough time passed to run a full upgrade, minimum is '$( displaytime $limit_time_seconds )', passed time is $( displaytime $time_passed )"
    fi
}


monthly_earnings_patreon_get(){
    local patreon_curl patreon_currency patreon_patrons patreon_curl patreon_pledge

    patreon_curl="$( curl -m 20 -Ls --user-agent "Mozilla 5.0"  "https://www.patreon.com/elive/about" | grep -E "(patron_count|pledge_sum)" | tr '"' "'" | tr ',' '\n' )"
    if [[ -z "$patreon_curl" ]] ; then
        sleep 2m
        patreon_curl="$( curl -m 20 -Ls --user-agent "Mozilla 5.0"  "https://www.patreon.com/elive/about" | grep -E "(patron_count|pledge_sum)" | tr '"' "'" | tr ',' '\n' )"
    fi
    patreon_currency="$( echo "$patreon_curl" | grep "'pledge_sum_currency':" | sed -e "s|^.*':||g" -e "s|,$||g" -e "s|'||g" )"
    read -r patreon_currency <<< "$patreon_currency"

    if [[ -n "$patreon_curl" ]] ; then
        if [[ -n "$patreon_currency" ]] ; then
            patreon_patrons="$( echo "$patreon_curl" | grep "'patron_count':" | sed -e "s|^.*':||g" -e "s|,$||g" | sort -V | tail -n 1 )"
            read -r patreon_patrons <<< "$patreon_patrons"
            patreon_pledge="$( echo "$patreon_curl" | grep "'pledge_sum':" | sed -e "s|^.*':||g" -e "s|,$||g" | sort -V | tail -n 1 )"
            read -r patreon_pledge <<< "$patreon_pledge"
            # remove the two last numbers (decimals)
            patreon_pledge="${patreon_pledge::-2}"
            if [[ -z "$patreon_pledge" ]] || [[ -z "$patreon_patrons" ]] ; then
                el_error "wrong data obtained from patreon curl:\n$patreon_curl"
            fi

            echo "$patreon_pledge $patreon_currency"
            return
        fi
    fi
}

patreon_members_update(){
    local timestamp limit_time_seconds num_updates time_passed

    # only if user has inserted a patreon email, update the status
    if [[ -z "$patreon_email" ]] ; then
        return
    fi

    # add a system email if we don't have any
    # if ! echo "$patreon_email" | grep -Eiqs '([[:alnum:]_.-]+@[[:alnum:]_.-]+?\.[[:alpha:].]{2,6})' ; then
    #     # 3 attempts
    #     local message_email
    #     message_email="$( printf "$( eval_gettext "Insert your email. It will be used as a computer identifier or to improve your experience in case you become a Premium user. Note that in such case is important to use the same one of your Patreon account." )" "" )"
    #
    #     if ! echo "$patreon_email" | grep -Eiqs '([[:alnum:]_.-]+@[[:alnum:]_.-]+?\.[[:alpha:].]{2,6})' ; then
    #         patreon_email="$( $guitool --entry --width=350 --title="Email Identifier" --text="$message_email" 2>/dev/null )"
    #     fi
    #     if ! echo "$patreon_email" | grep -Eiqs '([[:alnum:]_.-]+@[[:alnum:]_.-]+?\.[[:alpha:].]{2,6})' ; then
    #         patreon_email="$( $guitool --entry --width=350 --title="Email Identifier" --text="$message_email" 2>/dev/null )"
    #     fi
    #
    #     if echo "$patreon_email" | grep -Eiqs '([[:alnum:]_.-]+@[[:alnum:]_.-]+?\.[[:alpha:].]{2,6})' ; then
    #         sed -i "/^patreon_email=/d" "/etc/elive/settings" 2>/dev/null || true
    #         echo "patreon_email=\"$patreon_email\"" >> /etc/elive/settings
    #     else
    #         $guitool --error --text="$( eval_gettext "You have not inserted a valid email. This is needed in case you become a Premium supporter of Elive to improve your experience. Your email is only saved locally on your computer and not sent anywhere. However, you can also add a false email if you want but we recommend using your real one." )" 2>/dev/null
    #     fi
    # fi

    # know if still an active patreon user
    if echo "$patreon_email" | grep -Eiqs '([[:alnum:]_.-]+@[[:alnum:]_.-]+?\.[[:alpha:].]{2,6})' ; then
        patreon_email_checksum="$( echo "$patreon_email" | sha1sum | awk '{print $1}' )"

        # only after a min amount of time
        timestamp="/etc/elive/settings"
        limit_time_seconds="7200" # 2 hours
        if [[ -e "$timestamp" ]] ; then
            time_passed="$( echo "$(date +%s) - $( stat -c %Y "$timestamp" )" | LC_ALL="$EL_LC_EN" bc -l | sed -e 's|\..*$||g' )"
        else
            touch "$timestamp"
            time_passed="999999999999999999999999999"
        fi

        # add conf to know that is an active patreon
        if [[ "$time_passed" -gt "$limit_time_seconds" ]] ; then
            sed -i "/^is_premium_user=/d" "/etc/elive/settings" 2>/dev/null || true

            if curl -Ls -A "Mozilla/5.0" https://www.elivecd.org/files/patreon_members.txt | grep -qs "^${patreon_email_checksum}$" ; then
                echo "is_premium_user=\"1\"" >> /etc/elive/settings
            else
                echo "is_premium_user=\"0\"" >> /etc/elive/settings
            fi
        fi
    fi

    source /etc/elive/settings 2>/dev/null || true
}

#===  FUNCTION  ================================================================
#          NAME:  show_changelog
#   DESCRIPTION:  show the changelog message
#    PARAMETERS:  $1 = mode, $2 = message
#       RETURNS:  -
#===============================================================================
show_changelog(){
    # pre {{{
    local message_upgraded changelog mode

    mode="$1"
    shift
    changelog="$1"
    shift
    # }}}

    if [[ -z "$changelog" ]] || [[ -z "$mode" ]] ; then
        return
    fi

    el_debug "changelog:\n$changelog"

    if [[ "$mode" = "normal" ]] ; then
        message_upgraded="$( printf "$( eval_gettext "Your Elive has been upgraded with:" )" "" )"
    else
        message_upgraded=""
    fi

    # pre messages?
    case "$mode" in
        "pre")
            el_notify normal logo-elive "Elive Updates" "$( eval_gettext "Please follow the updating instructions if any..." )"
            ;;
        "post")
            el_notify normal logo-elive "Elive Updates" "$( eval_gettext "New features found" )"
            ;;
    esac

    # show changelog
    echo -e "${message_upgraded}$changelog" | $guitool  --width=610 --height=470 --text-info --cancel-label="Done" --title="Elive System Updated" 1>/dev/null 2>&1
    unset changelog

    # any next action after changelog?
    case "$mode" in
        "post")
            el_mark_state "upgraded" 2>/dev/null || true

            monthly_donations="$( monthly_earnings_patreon_get )"

            local message_donate_to_continue
            message_donate_to_continue="$( printf "$( eval_gettext "Elive is currently sustained with %s per month. Would you like to contribute to the Elive project in order to continue making updates and improvements?" )" "$monthly_donations" )"

            #if $guitool  --question --text="$( eval_gettext "Would you like to donate to this amazing project in order to keep making updates and fixes?" )" ; then
            if ! ((is_premium_user)) ; then
                if $guitool  --question --text="$message_donate_to_continue" 1>/dev/null 2>&1 ; then
                    #web-launcher "https://www.elivecd.org/donate/?id=elive-upgrader-tool"
                    web-launcher "https://www.patreon.com/elive"
                fi
            fi
            ;;
    esac

}

check_for_new_elive_version() {
    local upgrade_type="$1"
    local is_betatester="$2"
    local current_codename next_codename repo_url conf_var

    case "$upgrade_type" in
        alpha)
            if ! ((is_betatester)); then
                el_info "This distro upgrade is only avaialble for betatesters, consult the Elive Forum if you want to participate"
                return
            fi
            ;;
        beta)
            if ! ((is_premium_user)); then
                el_info "This distro upgrade is only avaialble for Premium users, consult the Elive Premium page to be one:  https://www.elivecd.org/premium"
                return
            fi
            ;;
        stable)
            el_info "Distro upgrade found"
            ;;
        *)
            el_warning "Unknown debian-upgrade type: $upgrade_type"
            return
            ;;
    esac

    if ((is_bookworm)); then
        current_codename="bookworm"
    elif ((is_bullseye)); then
        current_codename="bullseye"
    elif ((is_buster)); then
        current_codename="buster"
    elif ((is_wheezy)); then
        current_codename="wheezy"
    else
        return
    fi

    case "$current_codename" in
        "wheezy") next_codename="buster" ;;
        "buster") next_codename="bullseye" ;;
        "bullseye") next_codename="bookworm" ;;
        "bookworm") next_codename="trixie" ;; # For future releases
        *)
            return
            ;;
    esac

    el_config_get
    if [[ "${conf_debian_upgrade_notification}" = "never" ]]; then
        el_info "User opted out for new Debian version notifications. Ignoring..."
        return
    fi

    repo_url="https://repo.${next_codename}.elive.elivecd.org/dists/${next_codename}/Release"

    # Check if the repo for the next version exists
    if curl --output /dev/null --silent --head --fail "$repo_url"; then
        local message_new_version
        message_new_version="$( printf "$( eval_gettext "A new version of Elive based on Debian '%s' is available." )" "$next_codename" )"

        if ! el_dependencies_check "yad" &>/dev/null ; then
            el_dependencies_install "yad"
        fi

        local title
        title="$(eval_gettext "New Distro Upgrade Available")"
        $yad --title="$title" --text="$message_new_version" --text-align=center \
            --button="$(eval_gettext "Run Distro Upgrade"):0" \
            --button="$(eval_gettext "Remind Me Later"):1" \
            --button="$(eval_gettext "Never Ask Again"):2"

        local choice=$?

        case $choice in
            0) # Run Distro Upgrade
                el_info "Enabling distro upgrade to $next_codename for next reboot..."
                if sudo elive-upgrader-root --enable-distro-upgrade "$next_codename" ; then
                    local message_reboot
                    message_reboot="$( printf "$( eval_gettext "The system is now configured to upgrade to the next Elive version on the next reboot.\n\nPlease save your work and reboot your computer to start the upgrade process." )" "" )"
                    $guitool --info --text="$message_reboot" --no-cancel 1>/dev/null 2>&1
                    conf_debian_upgrade_notification=""
                else
                    local message_failed
                    message_failed="$( eval_gettext "Failed to enable the distro upgrade. Please check the logs for more information." )"
                    $guitool --error --text="$message_failed" 1>/dev/null 2>&1
                fi
                true
                ;;
            1) # Remind Me Later
                conf_debian_upgrade_notification="remind"
                ;;
            2) # Never Ask Again
                conf_debian_upgrade_notification="never"
                ;;
        esac

        el_config_save "conf_debian_upgrade_notification"
    fi
}

#===  FUNCTION  ================================================================
#          NAME:  run_hooks
#   DESCRIPTION:  run the hooks up to the last version ran
#    PARAMETERS:  $1 = user|root mode, $2 = pre|post
#       RETURNS:  -
#===============================================================================
run_hooks(){
    # pre {{{
    local mode changelog file
    el_debug
    el_security_function_loop || return 0

    mode="$1"
    shift
    prepost="$1"
    shift

    el_check_variables "mode"

    el_debug "running hooks in mode $mode"
    # }}}

    case "$mode" in
        root)
            # get versions {{{
            conf_version_upgrader="$( cat "/etc/elive-version" | grep "elive-fixes:" | awk '{print $2}' )"
            version_last_hook="$( find "${hooks_d}" -mindepth 1 -maxdepth 1 -type d | sed -e 's|^.*/||g' | sort -V | tail -1 )"
            read -r conf_version_upgrader <<< "$conf_version_upgrader"

            # first time, our system is fixed up to the actual version of elive, so nothing more is needed to do until there's a newer version of the tool
            if [[ -z "$conf_version_upgrader" ]] ; then
                conf_version_upgrader="$version_elive"
                echo -e "elive-fixes: $conf_version_upgrader" >> /etc/elive-version
            fi

            # - # get versions }}}
            ;;
        user)
            # get versions {{{
            el_config_get
            if [[ -z "$conf_version_upgrader" ]] ; then
                # reference to start from the version of elive built
                conf_version_upgrader="$( cat "/etc/elive-version" | grep "elive-version:" | awk '{print $2}' )"
                read -r conf_version_upgrader <<< "$conf_version_upgrader"
                el_config_save "conf_version_upgrader"
            fi

            version_last_hook="$( find "${hooks_d}" -mindepth 1 -maxdepth 1 -type d | sed -e 's|^.*/||g' | sort -V | tail -1 )"

            #}}}
            ;;
    esac


    # changes found
    if LC_ALL=C dpkg --compare-versions "$version_last_hook" "gt" "$conf_version_upgrader" ; then
        el_debug "version upgrader was $conf_version_upgrader and newest hook is $version_last_hook (older, so running hooks)"

        # loop in version dirs
        while read -ru 3 version
        do
            [[ -z "$version" ]] && continue

            # only if was not run yet
            if LC_ALL=C dpkg --compare-versions "$version" "gt" "$conf_version_upgrader" ; then
                el_info "elive-upgrader: hook version: $version"

                # loop in every hook for this version
                while read -ru 3 file
                do
                    [[ -z "$file" ]] && continue

                    el_debug "hook: $file"

                    case "$file" in
                        */debian-upgrade)
                            if [[ "$prepost" = "post" ]] ; then
                                local upgrade_type
                                upgrade_type=$(cat "$file")
                                check_for_new_elive_version "$upgrade_type" "$is_betatester"
                            fi
                            ;;
                        */pre-*.sh)
                            # run script
                            if [[ "$prepost" = "pre" ]] ; then
                                if [[ -x "$file" ]] ; then
                                    el_info "running script: $file"
                                    if ! "$file" ; then
                                        el_error "failed ${file}: $( "$file" )"
                                    fi
                                fi
                            fi
                            ;;
                        */post-*.sh)
                            # script
                            if [[ "$prepost" = "post" ]] ; then
                                if [[ -x "$file" ]] ; then
                                    el_info "running script: $file"
                                    if ! "$file" ; then
                                        el_error "failed ${file}: $( "$file" )"
                                    fi
                                fi
                            fi
                            ;;
                        # IMPORTANT: after the other ones
                        *.sh)
                            # DEPRECATED
                            if [[ -x "$file" ]] && [[ "$file" != *"pre-"* ]] && [[ "$file" != *"post-"* ]] ; then
                                el_info "running script: $file"
                                if ! "$file" ; then
                                    el_error "failed ${file}: $( "$file" )"
                                fi
                            fi
                            ;;

                        */post-CHANGELOG.txt)
                            # changelog
                            if [[ "$prepost" = "post" ]] ; then
                                if [[ -s "$file" ]] && [[ "$file" = *"/post-CHANGELOG.txt" ]] ; then
                                    # update: user don't needs to see any version number here
                                    #changelog="${changelog}\n\nVersion ${version}:\n$(cat "$file" )"
                                    if [[ -n "$changelog" ]] ; then
                                        changelog="${changelog}\n\n$(cat "$file" | grep -v "^#" )"
                                    else
                                        changelog="$(cat "$file" | grep -v "^#" )"
                                    fi
                                fi

                            fi

                            ;;
                        */pre-CHANGELOG.txt)
                            # changelog
                            if [[ "$prepost" = "pre" ]] ; then
                                if [[ -s "$file" ]] && [[ "$file" = *"/pre-CHANGELOG.txt" ]] ; then
                                    # update: user don't needs to see any version number here
                                    #changelog="${changelog}\n\nVersion ${version}:\n$(cat "$file" )"
                                    if [[ -n "$changelog" ]] ; then
                                        changelog="${changelog}\n\n$(cat "$file" | grep -v "^#" )"
                                    else
                                        changelog="$(cat "$file" | grep -v "^#" )"
                                    fi
                                fi

                            fi
                            ;;

                        # IMPORTANT: after the other ones
                        */CHANGELOG.txt)
                            # changelog
                            if [[ "$prepost" = "post" ]] ; then
                                if [[ -s "$file" ]] && [[ "$file" = *"/CHANGELOG.txt" ]] ; then
                                    # update: user don't needs to see any version number here
                                    #changelog="${changelog}\n\nVersion ${version}:\n$(cat "$file" )"
                                    changelog="${changelog}\n\n$(cat "$file" | grep -v "^#" )"
                                fi
                                if [[ "$mode" = "user" ]] ; then
                                    el_warning "Warning: changelogs should be shown as root mode, if you want user specific messages use the post- or pre- changelogs system"
                                fi
                            fi
                            ;;
                        */packages-to-upgrade.txt)
                            # only installs (update) if they are already installed
                            if [[ "$prepost" = "pre" ]] ; then
                                for package in $( cat "$file" | grep -v "^#" | tr ' ' '\n' )
                                do
                                    if [[ -n "$package" ]] ; then
                                        # only if is already installed
                                        if COLUMNS=1000 dpkg -l | grep -E "^(hi|ii)" | awk '{print $2}' | sed -e 's|:.*||g' | grep -qs "^${package}$" ; then
                                            el_array_member_add "$package" "${packages_to_upgrade[@]}" ; packages_to_upgrade=("${_out[@]}")
                                        fi
                                    fi
                                done
                            fi
                            ;;
                        */packages-to-install.txt)
                            # installs them
                            if [[ "$prepost" = "pre" ]] ; then
                                for package in $( cat "$file" | grep -v "^#" | tr ' ' '\n' )
                                do
                                    if [[ -n "$package" ]] ; then
                                        el_array_member_add "$package" "${packages_to_install[@]}" ; packages_to_install=("${_out[@]}")
                                    fi
                                done
                            fi
                            ;;
                        */packages-to-remove.txt)
                            if [[ "$prepost" = "pre" ]] ; then
                                for package in $( cat "$file" | grep -v "^#" | tr ' ' '\n' )
                                do
                                    if [[ -n "$package" ]] ; then
                                        el_array_member_unset "$package" "${packages_to_install[@]}" ; packages_to_install=("${_out[@]}")
                                        el_array_member_add "$package" "${packages_to_remove[@]}" ; packages_to_remove=("${_out[@]}")
                                    fi
                                done
                            fi
                            ;;
                        *)
                            el_error "elive-upgrader: filetype unknown: $file"
                            ;;
                    esac

                # sorted preference to run goes here:
                #done 3<<< "$( find "${hooks_d}/${version}/$mode" -mindepth 1 -maxdepth 1 -type f 2>/dev/null | sort | psort -- -p "\.sh$" )"
                done 3<<< "$( find "${hooks_d}/${version}/$mode" -mindepth 1 -maxdepth 1 -type f 2>/dev/null | sort | psort -- -p "debian-upgrade" -p "pre-"  -p "packages-to-remove" -p "packages-to-install" -p "packages-to-upgrade" -p "\.sh$" -p "CHANGELOG"  -p "post-" )"

                # update version, to know that we have run the hooks until here
                if [[ "$prepost" = "post" ]] ; then
                    if [[ "$mode" = "root" ]] ; then
                        sed -i "/^elive-fixes:/s/^.*$/elive-fixes: ${version}/" "/etc/elive-version"
                        conf_version_upgrader="$version"
                    fi
                    if [[ "$mode" = "user" ]] ; then
                        conf_version_upgrader="$version"
                        el_config_save "conf_version_upgrader"
                    fi
                fi

                # tell the user the system has been updated:
                notify_user_system_updated

            fi
        done 3<<< "$( find "${hooks_d}" -mindepth 1 -maxdepth 1 -type d | sed -e 's|^.*/||g' | sort -V )"
    else
        el_debug "version upgrader was $conf_version_upgrader and newest hook is $version_last_hook (newer, ignoring, they have already been run)"
    fi

    # update possible packages
    if [[ "$mode" = "root" ]] ; then
        if [[ -n "$packages_to_install" ]] || [[ -n "$packages_to_remove" ]] || [[ -n "$packages_to_upgrade" ]] ; then

            # clenaups
            packages_to_remove="$( echo "${packages_to_remove[@]}" )"
            packages_to_install="$( echo "${packages_to_install[@]}" )"
            packages_to_upgrade="$( echo "${packages_to_upgrade[@]}" )"

            # wait unlock
            apt_get moo 1>/dev/null 2>&1

            # update
            killall apt-get 2>/dev/null 1>&2 || true
            sync
            if ! is_quiet=1 el_aptget_update ; then
                sleep 20
                if ! is_quiet=1 el_aptget_update ; then
                    if [[ "$UID" = 0 ]] ; then
                        NOREPORTS=1 el_error "problem with el_aptget_update:\n$(apt-get update 2>&1)"
                    else
                        NOREPORTS=1 el_error "problem with el_aptget_update"
                    fi
                fi
            fi

            # fix
            # note: NEVER use timeout so it hangs apt-get
            # UPDATE: seems like it can work like this:   if ! timeout 1200 bash -c "unset TERM DISPLAY ; export DEBIAN_FRONTEND=noninteractive ; apt_get install -o Dpkg::Options::=\"--force-confdef\" -o Dpkg::Options::=\"--force-confnew\" -q -y elive-upgrader" ; then

            if ! apt_get -y -f install ; then
                if [[ "$UID" = 0 ]] ; then
                    NOREPORTS=1 el_error "problem with el_aptget_update:\n$(apt-get -y -f install 2>&1)"
                else
                    NOREPORTS=1 el_error "problem with apt-get -y -f install"
                fi
            fi

            # remove {{{
            if [[ -n "$packages_to_remove" ]] ; then
                el_debug "packages wanted to remove: $packages_to_remove"
                el_warning "removing packages not implemented yet; note: it will requrie the user confirmation to make sure that the system is not break?"
            fi

            # }}}
            # upgrade {{{
            if [[ -n "$packages_to_upgrade" ]] ; then
                el_debug "packages wanted to upgrade: $packages_to_upgrade"

                # first make sure that we clean it
                if ! apt_get clean ; then
                    el_error "cleaning apt cache packages"
                fi

                killall apt-get 2>/dev/null 1>&2 || true
                if apt_get install $APTGET_OPTIONS ${packages_to_upgrade} ; then
                    el_info "upgraded packages:\n$( echo "${packages_to_upgrade}" | tr ' ' '\n' | sort -u )"
                else
                    # update
                    sleep 5
                    if ! is_quiet=1 el_aptget_update ; then
                        NOREPORTS=1 el_error "problem with el_aptget_update"
                    fi

                    # try again
                    if apt_get install --reinstall $APTGET_OPTIONS ${packages_to_upgrade} ; then
                        el_info "upgraded packages:\n$( echo "${packages_to_upgrade}" | tr ' ' '\n' | sort -u )"
                    else
                        NOREPORTS=1 el_warning "failed to upgrade all packages in one shot: '${packages_to_upgrade}', trying with each one..."

                        # try with each one
                        for package in ${packages_to_upgrade}
                        do
                            if apt_get install --reinstall $APTGET_OPTIONS ${package} ; then
                                el_debug "upgraded one-to-one package: $package"
                            else
                                # update
                                sleep 4
                                if ! is_quiet=1 el_aptget_update ; then
                                    NOREPORTS=1 el_error "problem with el_aptget_update"
                                fi

                                # try again
                                if apt_get install --reinstall $APTGET_OPTIONS ${package} ; then
                                    el_debug "upgraded one-to-one package: $package"
                                else
                                    el_error "problem upgrading package ${package}:  $( TERM=linux DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical DEBCONF_NONINTERACTIVE_SEEN=true DEBCONF_NOWARNINGS=true  apt_get install --reinstall $APTGET_OPTIONS ${package} 2>&1 )"
                                fi
                            fi
                        done
                    fi
                fi
            fi
            # }}}
            # install {{{
            if [[ -n "$packages_to_install" ]] ; then
                el_debug "packages wanted to install: $packages_to_install"
                # TODO: ask for user confirmation and terminal showing? should be safer this way! like the installer mode does
                # TODO: we should integrate all this in el_package_install feature, it smells like a rewrite for it
                killall apt-get 2>/dev/null 1>&2 || true
                if apt_get install $APTGET_OPTIONS ${packages_to_install} ; then
                    el_info "installed packages:\n$( echo "${packages_to_install}" | tr ' ' '\n' | sort -u )"
                else
                    # update
                    sleep 5
                    if ! is_quiet=1 el_aptget_update ; then
                        NOREPORTS=1 el_error "problem with el_aptget_update"
                    fi

                    # try again
                    if apt_get install $APTGET_OPTIONS ${packages_to_install} ; then
                        el_info "installed packages:\n$( echo "${packages_to_install}" | tr ' ' '\n' | sort -u )"
                    else
                        NOREPORTS=1 el_warning "failed to install all packages in one shot: '${packages_to_install}', trying with each one..."

                        # try with each one
                        for package in ${packages_to_install}
                        do
                            if apt_get install $APTGET_OPTIONS ${package} ; then
                                el_debug "installed one-to-one package: $package"
                            else
                                # update
                                sleep 4
                                if ! is_quiet=1 el_aptget_update ; then
                                    NOREPORTS=1 el_error "problem with el_aptget_update"
                                fi

                                # try again
                                if apt_get install $APTGET_OPTIONS ${package} ; then
                                    el_debug "installed one-to-one package: $package"
                                else
                                    el_error "problem installing package ${package}:  $( TERM=linux DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical DEBCONF_NONINTERACTIVE_SEEN=true DEBCONF_NOWARNINGS=true apt-get $APTGET_OPTIONS install ${package} 2>&1 )"
                                fi
                            fi
                        done
                    fi
                fi
            fi
            # }}}
        fi
    fi


    # changelog to show?
    show_changelog "$prepost" "$changelog"

}

# function replacement for apt-get calls with a wait for unlock apt before to run
apt_get(){
    local is_waiting i
    i=0

    tput sc
    while fuser /var/lib/dpkg/lock /var/lib/apt/lists/lock  >/dev/null 2>&1 ; do
        case $(($i % 4)) in
            0 ) j="-" ;;
            1 ) j="\\" ;;
            2 ) j="|" ;;
            3 ) j="/" ;;
        esac
        tput rc
        echo -en "\r[$j] Waiting for other software managers to finish..."
        is_waiting=1

        sleep 0.5
        ((i=i+1))
    done

    # run what we want
    TERM=linux DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical DEBCONF_NONINTERACTIVE_SEEN=true DEBCONF_NOWARNINGS=true  apt-get "$@"
}


# vim: set foldmethod=marker :
