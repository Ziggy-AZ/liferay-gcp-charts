#!/usr/bin/env bash

set -eu

pass=0
fail=0

_pass() {
    echo "PASS: ${1}."
    pass=$((pass + 1))
}

_fail() {
    echo "FAIL: ${1}."
    fail=$((fail + 1))
}

main() {
    local chart_dir

    chart_dir="$(cd "$(dirname "${0}")/.." && pwd)"

    # overlay disabled - no liferay-overlay init container

    local disabled_output

    disabled_output=$(helm template test "${chart_dir}" --set overlay.enabled=false)

    if echo "${disabled_output}" | grep -q "name: liferay-overlay"
    then
        _fail "liferay-overlay init container rendered when overlay is disabled"
    else
        _pass "liferay-overlay init container absent when overlay is disabled"
    fi

    # overlay enabled - liferay-overlay init container present

    local enabled_output

    enabled_output=$(helm template test "${chart_dir}" \
        --set overlay.enabled=true \
        --set 'overlay.copy[0].into=/dest')

    if echo "${enabled_output}" | grep -q "name: liferay-overlay"
    then
        _pass "liferay-overlay init container present when overlay is enabled"
    else
        _fail "liferay-overlay init container not rendered when overlay is enabled"
    fi

    # default image is rclone

    if echo "${enabled_output}" | grep -q "image: rclone/rclone:1.66"
    then
        _pass "liferay-overlay uses rclone image by default"
    else
        _fail "liferay-overlay does not use expected rclone image"
    fi

    # image override - aws-cli

    local aws_output

    aws_output=$(helm template test "${chart_dir}" \
        --set overlay.enabled=true \
        --set 'overlay.copy[0].into=/dest' \
        --set overlay.image.repository=amazon/aws-cli \
        --set overlay.image.tag=2.27.63)

    if echo "${aws_output}" | grep -q "image: amazon/aws-cli:2.27.63"
    then
        _pass "liferay-overlay uses overridden aws-cli image"
    else
        _fail "liferay-overlay does not use overridden aws-cli image"
    fi

    # initScriptsVolumeName controls volumeMount name

    local custom_name_output

    custom_name_output=$(helm template test "${chart_dir}" \
        --set overlay.enabled=true \
        --set 'overlay.copy[0].into=/dest' \
        --set overlay.initScriptsVolumeName=custom-init-scripts)

    if echo "${custom_name_output}" | grep -q "name: custom-init-scripts"
    then
        _pass "volumeMount name tracks overlay.initScriptsVolumeName"
    else
        _fail "volumeMount name does not reflect overlay.initScriptsVolumeName"
    fi

    echo ""
    echo "Results: ${pass} passed, ${fail} failed."

    if [ "${fail}" -gt 0 ]
    then
        exit 1
    fi
}

main "${@}"
