#!/bin/bash
#SOURCE="$0"
#source /usr/lib/elive-tools/functions
#el_make_environment
. gettext.sh
TEXTDOMAIN="elive-upgrader"
export TEXTDOMAIN

# distro version
case "$( cat /etc/debian_version )" in
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


upgrade_system_delayed(){
    local timestamp limit_time_seconds num_updates
    timestamp="$HOME/.config/elive-upgrader/timestamp-last-upgrade"
    if ! [[ -d "$( dirname "$timestamp" )" ]] ; then
        mkdir -p "$( dirname "$timestamp" )"
        touch "$timestamp"
    fi

    # TODO: change it to monthly
    #limit_time_seconds="2419200" # 27 days (4 weeks - 1 day)  # monthly is the best option for now, to not annoy much the user with popups and updates are not so important, so will have from time to time some yummy improvements (also not much suggestions of desktop upgrades, etc)
    limit_time_seconds="1209600" # 14 days
    if ((is_buster)) ; then
        #limit_time_seconds="518400" # 6 days
        limit_time_seconds="1209600" # 14 days
    fi
    #limit_time_seconds="604800" # one week
    #limit_time_seconds="518400" # 6 days
    #limit_time_seconds="6" # tests only!

    if [[ "$( echo "$(date +%s) - $( stat -c %Y "$timestamp" )" | LC_ALL="$EL_LC_EN" bc -l | sed -e 's|\..*$||g' )" -gt "$limit_time_seconds" ]] ; then
        # get number of available updates
        num_updates="$( sudo elive-upgrader-root --updates-available )"
        el_debug "upgrades found: $num_updates"

        if [[ -n "$num_updates" ]] && [[ "$num_updates" -gt 0 ]] ; then
            # TODO: make this widget not-annoying (not popup in first page), use the trayer like elive-news
            if $guitool --question --text="${num_updates} $( eval_gettext "Updates available. Do you want to upgrade your Elive?" )" ; then

                $guitool --info --text="$( eval_gettext "Follow the instructions on the terminal when will appear, answering the questions. It's suggested to verify that the upgrade will not remove any needed package of your system." )"
                sudo elive-upgrader-root --upgrade
            fi
        fi

        sudo elive-upgrader-root --upgrade-firmwares

        # always mark/park until the next month, we dont want to run apt-get update at every start
        touch "$timestamp"
    fi
}

#===  FUNCTION  ================================================================
#          NAME:  run_hooks
#   DESCRIPTION:  run the hooks up to the last version ran
#    PARAMETERS:  $1 = user|root mode
#       RETURNS:  -
#===============================================================================
run_hooks(){
    # pre {{{
    local mode
    el_debug
    el_security_function_loop || return 0

    mode="$1"
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
            el_config_get "conf_version_upgrader"
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
                        *.sh)
                            # script
                            if [[ -x "$file" ]] && [[ "$file" = *".sh" ]] ; then
                                el_info "running script: $file"
                                if ! "$file" ; then
                                    el_error "failed ${file}: $( "$file" )"
                                fi
                            fi
                            ;;
                        */CHANGELOG.txt)
                            # changelog
                            if [[ -s "$file" ]] && [[ "$file" = *"/CHANGELOG.txt" ]] ; then
                                # update: user don't needs to see any version number here
                                #changelog="${changelog}\n\nVersion ${version}:\n$(cat "$file" )"
                                changelog="${changelog}\n\n$(cat "$file" )"
                            fi
                            ;;
                        */packages-to-upgrade.txt)
                            # only installs (update) if they are already installed
                            for package in $( cat "$file" | grep -v "^#" | tr ' ' '\n' )
                            do
                                if [[ -n "$package" ]] ; then
                                    # only if is already installed
                                    if COLUMNS=1000 dpkg -l | grep -E "^(hi|ii)" | awk '{print $2}' | sed -e 's|:.*||g' | grep -qs "^${package}$" ; then
                                        el_array_member_add "$package" "${packages_to_upgrade[@]}" ; packages_to_upgrade=("${_out[@]}")
                                    fi
                                fi
                            done
                            ;;
                        */packages-to-install.txt)
                            # installs them
                            for package in $( cat "$file" | grep -v "^#" | tr ' ' '\n' )
                            do
                                if [[ -n "$package" ]] ; then
                                    el_array_member_add "$package" "${packages_to_install[@]}" ; packages_to_install=("${_out[@]}")
                                fi
                            done
                            ;;
                        */packages-to-remove.txt)
                            for package in $( cat "$file" | grep -v "^#" | tr ' ' '\n' )
                            do
                                if [[ -n "$package" ]] ; then
                                    el_array_member_unset "$package" "${packages_to_install[@]}" ; packages_to_install=("${_out[@]}")
                                    el_array_member_add "$package" "${packages_to_remove[@]}" ; packages_to_remove=("${_out[@]}")
                                fi
                            done
                            ;;
                        *)
                            el_error "elive-upgrader: filetype unknown: $file"
                            ;;
                    esac
                done 3<<< "$( find "${hooks_d}/${version}/$mode" -mindepth 1 -maxdepth 1 -type f 2>/dev/null | sort | psort -- -p "\.sh$" )"

                # update version, to know that we have run the hooks until here
                if [[ "$mode" = "root" ]] ; then
                    sed -i "/^elive-fixes:/s/^.*$/elive-fixes: ${version}/" "/etc/elive-version"
                    conf_version_upgrader="$version"
                fi
                if [[ "$mode" = "user" ]] ; then
                    conf_version_upgrader="$version"
                    el_config_save "conf_version_upgrader"
                fi
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
                        el_error "problem with el_aptget_update:\n$(apt-get update 2>&1)"
                    else
                        el_error "problem with el_aptget_update"
                    fi
                fi
            fi

            # fix
            # note: NEVER use timeout so it hangs apt-get
            # UPDATE: seems like it can work like this:   if ! timeout 1200 bash -c "unset TERM DISPLAY ; export DEBIAN_FRONTEND=noninteractive ; apt_get install -o Dpkg::Options::=\"--force-confdef\" -o Dpkg::Options::=\"--force-confnew\" -q -y elive-upgrader" ; then

            if ! apt_get -y -f install ; then
                if [[ "$UID" = 0 ]] ; then
                    el_error "problem with el_aptget_update:\n$(apt-get -y -f install 2>&1)"
                else
                    el_error "problem with apt-get -y -f install"
                fi
            fi

            # remove
            if [[ -n "$packages_to_remove" ]] ; then
                el_debug "packages wanted to remove: $packages_to_remove"
                el_warning "removing packages not implemented yet; note: it will requrie the user confirmation to make sure that the system is not break?"
            fi

            # install
            if [[ -n "$packages_to_install" ]] ; then
                el_debug "packages wanted to install: $packages_to_install"
                # TODO: ask for user confirmation and terminal showing? should be safer this way! like the installer mode does
                # TODO: we should integrate all this in el_package_install feature, it smells like a rewrite for it
                killall apt-get 2>/dev/null 1>&2 || true
                if apt_get install $APTGET_OPTIONS ${packages_to_install} ; then
                    el_info "installed packages"
                else
                    # update
                    sleep 5
                    if ! is_quiet=1 el_aptget_update ; then
                        el_error "problem with el_aptget_update"
                    fi

                    # try again
                    if apt_get install $APTGET_OPTIONS ${packages_to_install} ; then
                        el_info "installed packages: ${packages_to_install}"
                    else
                        el_warning "failed to install all packages in one shot: '${packages_to_install}', trying with each one..."

                        # try with each one
                        for package in ${packages_to_install}
                        do
                            if apt_get install $APTGET_OPTIONS ${package} ; then
                                el_debug "installed one-to-one package: $package"
                            else
                                # update
                                sleep 4
                                if ! is_quiet=1 el_aptget_update ; then
                                    el_error "problem with el_aptget_update"
                                fi

                                # try again
                                if apt_get install $APTGET_OPTIONS ${package} ; then
                                    el_debug "installed one-to-one package: $package"
                                else
                                    el_error "problem installing package ${package}:  $( TERM=linux DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical DEBCONF_NONINTERACTIVE_SEEN=true DEBCONF_NOWARNINGS=true apt-get install $APTGET_OPTIONS ${package} 2>&1 )"
                                fi
                            fi
                        done
                    fi
                fi
            fi
            # upgrade
            if [[ -n "$packages_to_upgrade" ]] ; then
                el_debug "packages wanted to upgrade: $packages_to_upgrade"

                # first make sure that we clean it
                if ! apt_get clean ; then
                    el_error "cleaning apt cache packages"
                fi

                killall apt-get 2>/dev/null 1>&2 || true
                if apt_get install --reinstall $APTGET_OPTIONS ${packages_to_upgrade} ; then
                    el_info "upgraded packages"
                else
                    # update
                    sleep 5
                    if ! is_quiet=1 el_aptget_update ; then
                        el_error "problem with el_aptget_update"
                    fi

                    # try again
                    if apt_get install --reinstall $APTGET_OPTIONS ${packages_to_upgrade} ; then
                        el_info "upgraded packages: ${packages_to_upgrade}"
                    else
                        el_warning "failed to upgrade all packages in one shot: '${packages_to_upgrade}', trying with each one..."

                        # try with each one
                        for package in ${packages_to_upgrade}
                        do
                            if apt_get install --reinstall $APTGET_OPTIONS ${package} ; then
                                el_debug "upgraded one-to-one package: $package"
                            else
                                # update
                                sleep 4
                                if ! is_quiet=1 el_aptget_update ; then
                                    el_error "problem with el_aptget_update"
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
        fi
    fi

    # changelog to show?
    if [[ -n "$changelog" ]] ; then
        local message_upgraded
        message_upgraded="$( printf "$( eval_gettext "Your Elive has been upgraded with:" )" "" )"

        el_debug "changelog:\n$changelog"

        echo -e "${message_upgraded}$changelog" | $guitool  --height=400 --text-info --cancel-label="Done" --title="Elive System Updated"
        unset changelog
        el_mark_state "upgraded" 2>/dev/null || true

        if $guitool  --question --text="$( eval_gettext "Donate to this amazing project in order to keep making updates and fixes?" )" ; then
            web-launcher "http://www.elivecd.org/donate/?id=elive-upgrader-tool"
        fi

    fi

}


# vim: set foldmethod=marker :
