#@TYPE: Machine
#@NAME: common_pc
#@DESCRIPTION: Machine configuration for running a common x86

DEFAULTTUNE ?= "x86-64"
require conf/machine/include/tune-core2.inc

MACHINE_FEATURES += "x86"
