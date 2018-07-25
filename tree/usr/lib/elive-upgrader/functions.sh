#!/bin/bash
SOURCE="$0"
#source /usr/lib/elive-tools/functions
#el_make_environment
. gettext.sh
TEXTDOMAIN="elive-upgrader"
export TEXTDOMAIN

DEBIAN_VERSION="$( tail -1 /etc/debian_version )"
if dpkg --compare-versions "$DEBIAN_VERSION" gt 8 ; then
    APTGET_OPTIONS="-o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confnew -y --allow-downgrades"
else
    APTGET_OPTIONS="-o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confnew -y --force-yes"
fi

upgrade_system_delayed(){
    local timestamp limit_time_seconds num_updates
    timestamp="$HOME/.config/elive-upgrader/timestamp-last-upgrade"
    if ! [[ -d "$( dirname "$timestamp" )" ]] ; then
        mkdir -p "$( dirname "$timestamp" )"
        touch "$timestamp"
    fi

    # TODO: change it to monthly
    #limit_time_seconds="2419200" # 27 days (4 weeks - 1 day)  # monthly is the best option for now, to not annoy much the user with popups and updates are not so important, so will have from time to time some yummy improvements (also not much suggestions of desktop ugprades, etc)
    limit_time_seconds="1209600" # 14 days
    #limit_time_seconds="604800" # one week
    #limit_time_seconds="518400" # 6 days
    #limit_time_seconds="6" # tests only!

    if [[ "$( echo "$(date +%s) - $( stat -c %Y "$timestamp" )" | LC_ALL="$EL_LC_EN" bc -l | sed -e 's|\..*$||g' )" -gt "$limit_time_seconds" ]] ; then
        # get number of available updates
        num_updates="$( sudo elive-upgrader-root --updates-available )"

        if [[ -n "$num_updates" ]] && [[ "$num_updates" -gt 0 ]] ; then
            # TODO: make this widget not-annoying (not popup in first page), use the trayer like elive-news
            if zenity --question --text="${num_updates} $( eval_gettext "Updates available. Do you want to upgrade your Elive?" )" ; then

                zenity --info --text="$( eval_gettext "Please follow the instructions in the terminal, and type what will ask you." )"
                sudo elive-upgrader-root --upgrade
            fi
        fi

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
    el_security_function_loop || return

    mode="$1"
    el_check_variables "mode"

    # }}}

    case "$mode" in
        root)
            # get versions {{{
            version_upgrader="$( cat "/etc/elive-version" | grep "elive-fixes:" | awk '{print $2}' )"
            version_last_hook="$( find "${hooks_d}" -mindepth 1 -maxdepth 1 -type d | sed -e 's|^.*/||g' | sort -n | tail -1 )"
            read -r version_upgrader <<< "$version_upgrader"

            # first time, our system is fixed up to the actual version of elive, so nothing more is needed to do until there's a newer version of the tool
            if [[ -z "$version_upgrader" ]] ; then
                version_upgrader="$version_elive"
                echo -e "elive-fixes: $version_upgrader" >> /etc/elive-version
            fi

            # - # get versions }}}
            ;;
        user)
            # get versions {{{
            el_config_get "version_upgrader"
            if [[ -z "$version_upgrader" ]] ; then
                # reference to start from the version of elive built
                version_upgrader="$( cat "/etc/elive-version" | grep "elive-version:" | awk '{print $2}' )"
                read -r version_upgrader <<< "$version_upgrader"
                el_config_save "version_upgrader"
            fi

            version_last_hook="$( find "${hooks_d}" -mindepth 1 -maxdepth 1 -type d | sed -e 's|^.*/||g' | sort -n | tail -1 )"

            #}}}
            ;;
    esac

    if LC_ALL=C dpkg --compare-versions "$version_last_hook" "gt" "$version_upgrader" ; then

        # loop in version dirs
        while read -ru 3 version
        do
            [[ -z "$version" ]] && continue

            # only if was not run yet
            if LC_ALL=C dpkg --compare-versions "$version" "gt" "$version_upgrader" ; then
                el_info "elive-upgrader: hook version: $version"

                # loop in every hook for this version
                while read -ru 3 file
                do
                    [[ -z "$file" ]] && continue

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
                                        el_array_member_add "$package" "${packages_to_install[@]}" ; packages_to_install=("${_out[@]}")
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
                done 3<<< "$( find "${hooks_d}/${version}/$mode" -mindepth 1 -maxdepth 1 -type f 2>/dev/null )"

                # update version, to know that we have run the hooks until here
                if [[ "$mode" = "root" ]] ; then
                    sed -i "/^elive-fixes:/s/^.*$/elive-fixes: ${version}/" "/etc/elive-version"
                    version_upgrader="$version"
                fi
                if [[ "$mode" = "user" ]] ; then
                    version_upgrader="$version"
                    el_config_save "version_upgrader"
                fi
            fi
        done 3<<< "$( find "${hooks_d}" -mindepth 1 -maxdepth 1 -type d | sed -e 's|^.*/||g' | sort -n )"
    fi

    # update possible packages
    if [[ "$mode" = "root" ]] ; then
        if [[ -n "$packages_to_install" ]] || [[ -n "$packages_to_remove" ]] ; then

            # clenaups
            packages_to_remove="$( echo "${packages_to_remove[@]}" )"
            packages_to_install="$( echo "${packages_to_install[@]}" )"

            # update
            if ! is_quiet=1 el_aptget_update ; then
                el_error "problem with el_aptget_update"
            fi

            # fix
            # note: NEVER use timeout so it hangs apt-get
            # UPDATE: seems like it can work like this:   if ! timeout 1200 bash -c "unset TERM DISPLAY ; export DEBIAN_FRONTEND=noninteractive ; apt-get install -o Dpkg::Options::=\"--force-confdef\" -o Dpkg::Options::=\"--force-confnew\" -q -y elive-upgrader" ; then

            if ! DEBIAN_FRONTEND=noninteractive apt-get -f install ; then
                el_error "problem with apt-get -f install"
            fi

            # remove
            if [[ -n "$packages_to_remove" ]] ; then
                el_warning "removing packages not implemented yet; note: it will requrie the user confirmation to make sure that the system is not break?"
            fi

            # install
            if [[ -n "$packages_to_install" ]] ; then
                # TODO: ask for user confirmation and terminal showing? should be safer this way! like the installer mode does
                # TODO: we should integrate all this in el_package_install feature, it smells like a rewrite for it
                if DEBIAN_FRONTEND=noninteractive apt-get install $APTGET_OPTIONS ${packages_to_install} ; then
                    el_info "installed packages: ${packages_to_install}"
                else
                    el_warning "failed to install all packages in one shot: '${packages_to_install}', trying with each one..."

                    # try with each one
                    for package in ${packages_to_install}
                    do
                        if DEBIAN_FRONTEND=noninteractive apt-get install $APTGET_OPTIONS ${package} ; then
                            el_debug "installed one-to-one package: $package"
                        else
                            el_error "problem installing package ${package}:  $( DEBIAN_FRONTEND=noninteractive apt-get install $APTGET_OPTIONS ${package} 2>&1 )"
                        fi
                    done
                fi
            fi
        fi
    fi

    # changelog to show?
    if [[ -n "$changelog" ]] ; then
        local message_upgraded
        message_upgraded="$( printf "$( eval_gettext "Your Elive has been upgraded with:" )" "" )"

        echo -e "${message_upgraded}$changelog" | zenity --text-info --title="Elive System Updated"
        unset changelog
        el_mark_state "upgraded" 2>/dev/null || true

        if zenity --question --text="$( eval_gettext "Donate to this amazing project in order to keep supporting updates and fixes?" )" ; then
            web-launcher "http://www.elivecd.org/donate/?id=elive-upgrader-tool"
        fi

    fi

}


# vim: set foldmethod=marker :
