BB_DEFAULT_TASK ?= "build"
CLASSOVERRIDE ?= "class-target"

inherit patch
inherit utility-tasks

OE_IMPORTS += "os sys time oe.path oe.types oe.utils"
OE_IMPORTS[type] = "list"

def oe_import(d):
    import sys

    bbpath = d.getVar("BBPATH").split(":")
    sys.path[0:0] = [os.path.join(dir, "lib") for dir in bbpath]

    def inject(name, value):
        """Make a python object accessible from the metadata"""
        if hasattr(bb.utils, "_context"):
            bb.utils._context[name] = value
        else:
            __builtins__[name] = value

    import oe.data
    for toimport in oe.data.typed_value("OE_IMPORTS", d):
        imported = __import__(toimport)
        inject(toimport.split(".", 1)[0], imported)

    return ""

# We need the oe module name space early (before INHERITs get added)
OE_IMPORTED := "${@oe_import(d)}"

def base_set_filespath(path, d):
    filespath = []
    extrapaths = (d.getVar("FILESEXTRAPATHS") or "")
    # Remove default flag which was used for checking
    extrapaths = extrapaths.replace("__default:", "")
    # Don't prepend empty strings to the path list
    if extrapaths != "":
        path = extrapaths.split(":") + path
    # The ":" ensures we have an 'empty' override
    overrides = (":" + (d.getVar("FILESOVERRIDES") or "")).split(":")
    overrides.reverse()
    for o in overrides:
        for p in path:
            if p != "":
                filespath.append(os.path.join(p, o))
    return ":".join(filespath)

FILESPATH = "${@base_set_filespath(["${FILE_DIRNAME}/${BP}", "${FILE_DIRNAME}/${BPN}", "${FILE_DIRNAME}/files"], d)}"
# THISDIR only works properly with imediate expansion as it has to run
# in the context of the location its used (:=)
THISDIR = "${@os.path.dirname(d.getVar('FILE'))}"

def prune_suffix(var, suffixes, d):
    # See if var ends with any of the suffixes listed and
    # remove it if found
    for suffix in suffixes:
        if var.endswith(suffix):
            var = var.replace(suffix, "")

    prefix = d.getVar("MLPREFIX")
    if prefix and var.startswith(prefix):
        var = var.replace(prefix, "")

    return var

def base_prune_suffix(var, suffixes, d):
    return prune_suffix(var, suffixes, d)

def base_cpu_count():
    import multiprocessing
    return multiprocessing.cpu_count()

base_update_conf_value() {
    local config_file=$1
    local key=$2
    local value=$3
    local exists=`grep "^[^\#]*${key}.*=" "${config_file}"`

    if [ -z "${exists}" ] ; then
        # make placeholder
        echo "${key} = " >> "${config_file}"
    fi
    # substitute
    sed -i "s%\(^${key} *[?+:]*= *\).*%\1\"${value}\"%" "${config_file}"
}

base_adjust_conf_value() {
    local config_file=$1
    local key=$2
    local value=$3
    local adjustment=$4

    echo "${key} ${adjustment} "\"${value}\" >> "${config_file}"
}

base_set_conf_value() {
   base_adjust_conf_value "$1" "$2" "$3" "="
}

base_add_conf_value() {
    base_adjust_conf_value "$1" "$2" "$3" "+="
}

base_remove_conf_value() {
    base_adjust_conf_value "$1" "$2" "$3" "-="
}

addtask fetch
do_fetch[dirs] = "${DL_DIR}"
do_fetch[vardeps] += "SRCREV"
python base_do_fetch() {
    src_uri = (d.getVar('SRC_URI') or "").split()
    if len(src_uri) == 0:
        return

    bb.debug(1, "Fetching: %s" % "\n".join(src_uri))
    try:
        fetcher = bb.fetch2.Fetch(src_uri, d)
        fetcher.download()
    except bb.fetch2.BBFetchException as e:
        bb.fatal(str(e))
}

addtask unpack after do_fetch
do_unpack[dirs] = "${WORKDIR}"

python () {
    if d.getVar('S') != d.getVar('WORKDIR'):
        d.setVarFlag('do_unpack', 'cleandirs', '${S}')
    else:
        d.setVarFlag('do_unpack', 'cleandirs', os.path.join('${S}', 'patches'))
}
python base_do_unpack() {
    src_uri = (d.getVar('SRC_URI') or "").split()
    if len(src_uri) == 0:
        return

    try:
        fetcher = bb.fetch2.Fetch(src_uri, d)
        bb.debug(1, "Unpacking: %s" % "\n".join(d.getVar('WORKDIR').split()))
        fetcher.unpack(d.getVar('WORKDIR'))
        bb.debug(1, "Unpacking: %s" % "\n".join(d.getVar('S').split()))
    except bb.fetch2.BBFetchException as e:
        bb.fatal(str(e))
}

addtask configure after do_patch
base_do_configure() {
    :
}

addtask compile after do_configure
base_do_compile() {
    :
}

addtask install after do_compile
base_do_install() {
    :
}

addtask package after do_install
base_do_package() {
    :
}

addtask populate_sysroot after do_install
do_populate_sysroot() {
    :
}

addtask populate_sdk after do_populate_sysroot
do_populate_sdk() {
    :
}

addtask collect_build_history after do_populate_sdk
do_collect_build_history() {
    :
}

addtask populate_sstate_cache after do_collect_build_history
do_populate_sstate_cache() {
    :
}

addtask build after do_populate_sstate_cache
do_build () {
    :
}

EXPORT_FUNCTIONS do_fetch do_unpack do_configure do_compile do_install do_package
EXPORT_FUNCTIONS do_populate_sdk do_collect_build_history do_populate_sstate_cache
EXPORT_FUNCTIONS cpu_count prune_suffix update_conf_value
