################################################################################
# FIXME: If the variable expansion syntax is used on a variable that
# does not exist, the string is kept as is.
# E.g. trying to expand non-existing XT_POPULATE_SDK will result
# in ${XT_POPULATE_SDK} string, thus making [ -n ${XT_POPULATE_SDK}] check
# always be true.
#
# Workaround this by explicitly expanding those variables we depend on
# either to the value or empty string.
#
# N.B. If the variable is set, then it can be used as is, so
# only use expanded variables for tests, e.g. [ -n ]
#
# N.B. This is not needed for those variables that are handled by bitbake
# itself, e.g. DL_DIR etc.
################################################################################

EXPANDED_XT_BB_LAYERS_FILE = "${@d.getVar('XT_BB_LAYERS_FILE') or ''}"
EXPANDED_XT_BB_LOCAL_CONF_FILE = "${@d.getVar('XT_BB_LOCAL_CONF_FILE') or ''}"
EXPANDED_XT_SHARED_ROOTFS_DIR = "${@d.getVar('XT_SHARED_ROOTFS_DIR') or ''}"
EXPANDED_XT_SSTATE_CACHE_MIRROR_DIR = "${@d.getVar('XT_SSTATE_CACHE_MIRROR_DIR') or ''}"
EXPANDED_XT_ALLOW_SSTATE_CACHE_MIRROR_USE = "${@d.getVar('XT_ALLOW_SSTATE_CACHE_MIRROR_USE') or ''}"
EXPANDED_XT_POPULATE_SDK = "${@d.getVar('XT_POPULATE_SDK') or ''}"
EXPANDED_XT_POPULATE_SSTATE_CACHE = "${@d.getVar('XT_POPULATE_SSTATE_CACHE') or ''}"

REAL_XT_BB_CONFIG_CMD = "${@d.getVar('XT_BB_CONFIG_CMD') or 'source poky/oe-init-build-env'}"
REAL_XT_BB_RUN_CMD = "${@d.getVar('XT_BB_RUN_CMD') or 'source poky/oe-init-build-env'}"

build_yocto_configure() {
    local local_conf="${S}/build/conf/local.conf"

    cd ${S}
    ${REAL_XT_BB_CONFIG_CMD}
    if [ -f "${S}/${EXPANDED_XT_BB_LAYERS_FILE}" ] ; then
        cp "${S}/${XT_BB_LAYERS_FILE}" "${S}/build/conf/bblayers.conf"
    fi
    if [ -f "${S}/${EXPANDED_XT_BB_LOCAL_CONF_FILE}" ] ; then
        cp "${S}/${XT_BB_LOCAL_CONF_FILE}" "${local_conf}"
    fi
    # update local.conf so inner build uses our folders
    if [ -f "${local_conf}" ] ; then
        if [ -n "${MACHINE}" ] ; then
                # FIXME: inner build cannot use the same machine name because
                # of machine configuration file name clashes with the original
                # one from BSP, e.g. if original BSP provides my-machine.conf
                # and we want to modify it then there will also be our
                # my-machine.conf. But, we cannot guarantee that our conf file
                # will be picked by bitbake first.
                # Add xen-troops suffix, so inner build uses
                # our machine without races
                base_update_conf_value "${local_conf}" MACHINE "${MACHINE}-xt"
        fi
        if [ -n "${DL_DIR}" ] ; then
                base_update_conf_value "${local_conf}" DL_DIR "${DL_DIR}"
        fi
        if [ -n "${SSTATE_DIR}" ] ; then
                base_update_conf_value "${local_conf}" SSTATE_DIR "${SSTATE_DIR}/${PN}"
        fi
        if [ -n "${DEPLOY_DIR}" ] ; then
                base_update_conf_value "${local_conf}" DEPLOY_DIR "${DEPLOY_DIR}/${PN}"
        fi
        if [ -n "${LOG_DIR}" ] ; then
                base_update_conf_value "${local_conf}" LOG_DIR "${LOG_DIR}/${PN}"
        fi
        if [ -n "${BUILDHISTORY_DIR}" ] ; then
                base_update_conf_value "${local_conf}" BUILDHISTORY_DIR "${BUILDHISTORY_DIR}/${PN}"
        fi
        if [ -n "${EXPANDED_XT_POPULATE_SDK}" ] ; then
                base_update_conf_value "${local_conf}" XT_POPULATE_SDK "${XT_POPULATE_SDK}"
        fi
        if [ -n "${EXPANDED_XT_POPULATE_SSTATE_CACHE}" ] ; then
                base_update_conf_value "${local_conf}" XT_POPULATE_SSTATE_CACHE "${XT_POPULATE_SSTATE_CACHE}"
        fi
        if [ -n "${EXPANDED_XT_SHARED_ROOTFS_DIR}" ] ; then
                base_update_conf_value "${local_conf}" XT_SHARED_ROOTFS_DIR "${XT_SHARED_ROOTFS_DIR}"
        fi
        if [ -n "${EXPANDED_XT_SSTATE_CACHE_MIRROR_DIR}" ] ; then
                base_update_conf_value "${local_conf}" XT_SSTATE_CACHE_MIRROR_DIR "${XT_SSTATE_CACHE_MIRROR_DIR}"
                if [ "${EXPANDED_XT_ALLOW_SSTATE_CACHE_MIRROR_USE}" == "1" ] ; then
                        # force to what we want
                        echo "SSTATE_MIRRORS=\"file://.* file://${XT_SSTATE_CACHE_MIRROR_DIR}/PATH\"" >> "${local_conf}"
                fi
        fi
        base_add_conf_value "${local_conf}" INHERIT buildhistory
        base_update_conf_value "${local_conf}" BUILDHISTORY_COMMIT 1
    fi
}

build_yocto_add_bblayer() {
    cd ${S}

    ${REAL_XT_BB_RUN_CMD} && bitbake-layers add-layer "${S}/${XT_BBLAYER}"
}

build_yocto_set_generic_machine() {
    local local_conf="${S}/build/conf/local.conf"
    cd ${S}

    base_update_conf_value "${local_conf}" MACHINE "generic-armv8-xt"
}

build_yocto_exec_bitbake() {
    cd ${S}

    ${REAL_XT_BB_RUN_CMD} && bitbake ${XT_BB_CMDLINE}
}

python do_configure() {
    bb.build.exec_func("build_yocto_configure", d)
    # add layers to bblayers.conf
    layers = (d.getVar("XT_QUIRK_BB_ADD_LAYER") or "").split()
    if layers:
        if "meta-xt-images-generic-armv8" in layers:
            bb.build.exec_func("build_yocto_set_generic_machine", d)
        for layer in layers:
            bb.debug(1, "Adding to bblayers.conf: " + str(layer.split()))
            d.setVar('XT_BBLAYER', str(layer))
            bb.build.exec_func("build_yocto_add_bblayer", d)
}

do_compile() {
    cd ${S}
    ${REAL_XT_BB_RUN_CMD}
    bitbake "${XT_BB_IMAGE_TARGET}"
}

do_populate_sdk() {
    if [ -n "${EXPANDED_XT_POPULATE_SDK}" ] ; then
        cd ${S}
        # do not populate SDK for initramfs
        for target in "${XT_BB_IMAGE_TARGET}"
        do
            if [[ $target =~ initramfs ]]; then
                echo "Skipping populate SDK task for $target"
            else
                echo "Populating SDK for $target"
                ${REAL_XT_BB_RUN_CMD} && bitbake $target -c populate_sdk
            fi
        done
    fi
}

do_collect_build_history() {
    cd ${S}
    ${REAL_XT_BB_RUN_CMD}
    HISTORY_DIR="${BUILDHISTORY_DIR}/${PN}"
    buildhistory-collect-srcrevs -a -p "${HISTORY_DIR}" > "${HISTORY_DIR}/build-versions.inc"
}

do_populate_sstate_cache() {
    if [ -n "${EXPANDED_XT_POPULATE_SSTATE_CACHE}" ] ; then
        if [ -n "${EXPANDED_XT_SSTATE_CACHE_MIRROR_DIR}" ] ; then
            install -d "${XT_SSTATE_CACHE_MIRROR_DIR}"
            cp -a "${SSTATE_DIR}/${PN}/." "${XT_SSTATE_CACHE_MIRROR_DIR}/" || true
        fi
    fi
}

do_build() {
    :
}
