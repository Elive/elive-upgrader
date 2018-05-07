#!/bin/bash
#SOURCE="$0"
#source /usr/lib/elive-tools/functions
#el_make_environment
#. gettext.sh

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
        while read -ru 3 version
        do
            [[ -z "$version" ]] && continue

            if LC_ALL=C dpkg --compare-versions "$version" "gt" "$version_upgrader" ; then
                el_info "elive-upgrader: hook version: $version"

                while read -ru 3 file
                do
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
                        *CHANGELOG.txt)
                            # changelog
                            if [[ -s "$file" ]] && [[ "$file" = *"/CHANGELOG.txt" ]] ; then
                                # update: user don't needs to see any version number here
                                #changelog="${changelog}\n\nVersion ${version}:\n$(cat "$file" )"
                                changelog="${changelog}\n\n$(cat "$file" )"
                            fi
                            ;;
                        *)
                            el_error "elive-upgrader: filetype unknown: $file"
                            ;;
                    esac
                done 3<<< "$( find "${hooks_d}/${version}/$mode" -mindepth 1 -maxdepth 1 -type f )"

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

    # changelog to show?
    if [[ -n "$changelog" ]] ; then
        local message_upgraded
        message_upgraded="$( printf "$( eval_gettext "Your Elive has been upgraded with:" )" "" )"

        echo -e "${message_upgraded}$changelog" | zenity --text-info --title="Elive System Updated"
        unset changelog
    fi
}


# vim: set foldmethod=marker :