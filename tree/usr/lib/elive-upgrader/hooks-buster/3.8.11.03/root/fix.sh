#!/bin/bash


cat > "/etc/apt/apt.conf.d/60ignore_repo_date_check.conf" << EOF
Acquire
{
    Check-Valid-Until "false";
    Check-Date "false";
}
EOF
