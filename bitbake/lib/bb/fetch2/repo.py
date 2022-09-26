# ex:ts=4:sw=4:sts=4:et
# -*- tab-width: 4; c-basic-offset: 4; indent-tabs-mode: nil -*-
"""
BitBake "Fetch" repo (git) implementation

"""

# Copyright (C) 2009 Tom Rini <trini@embeddedalley.com>
#
# Based on git.py which is:
#Copyright (C) 2005 Richard Purdie
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

import os
import bb
from   bb.fetch2 import FetchMethod
from   bb.fetch2 import runfetchcmd
from   bb.fetch2 import logger

class Repo(FetchMethod):
    """Class to fetch a module or modules from repo (git) repositories"""
    def supports(self, ud, d):
        """
        Check to see if a given url can be fetched with repo.
        """
        return ud.type in ["repo"]

    def urldata_init(self, ud, d):
        """
        We don"t care about the git rev of the manifests repository, but
        we do care about the manifest to use.  The default is "default".
        We also care about the branch or tag to be used.  The default is
        "master".
        """

        ud.proto = ud.parm.get('protocol', 'git')
        ud.branch = ud.parm.get('branch', 'master')
        ud.manifest = ud.parm.get('manifest', 'default.xml')
        ud.groups = ud.parm.get('groups', '')
        ud.depth = ud.parm.get('depth', '')
        ud.directpath = ud.parm.get('directpath', '0')
        if not ud.manifest.endswith('.xml'):
            ud.manifest += '.xml'

        ud.localfile = d.expand("repo_%s%s_%s_%s.tar.gz" % (ud.host, ud.path.replace("/", "."), ud.manifest, ud.branch))
        repodir = d.getVar("REPODIR") or os.path.join(d.getVar("DL_DIR"), "repo")
        if ud.directpath == "1":
            ud.repodir = repodir
        else:
            gitsrcname = "%s%s" % (ud.host, ud.path.replace("/", "."))
            ud.codir = os.path.join(repodir, gitsrcname, ud.manifest)
            ud.repodir = os.path.join(ud.codir, "repo")

    def sync(self, destdir, d):
        # repo can separate the "network" sync (the git fetch part, network bound)
        # from the "local" sync (the git rebase part, compute & i/o bound).
        num_jobs = d.getVar("BB_NUMBER_THREADS", True) or "1"
        runfetchcmd("repo sync -c -n -j%s" % num_jobs, d, workdir=destdir)
        runfetchcmd("repo sync -c -l -j%s" % num_jobs, d, workdir=destdir)


    def download(self, ud, d):
        """Fetch url"""

        # For performance reasons we do not use tar.gz if 'directpath' is specified in SRC_URI
        if ud.directpath != "1" and os.access(os.path.join(d.getVar("DL_DIR"), ud.localfile), os.R_OK):
            logger.debug(1, "%s already exists (or was stashed). Skipping repo init / sync.", ud.localpath)
            return

        if ud.user:
            username = ud.user + "@"
        else:
            username = ""

        if ud.groups:
            use_groups = "--groups " + ud.groups
        else:
            use_groups = ""

        if ud.depth:
            use_depth = "--depth=" + ud.depth
        else:
            use_depth = ""

        bb.utils.mkdirhier(ud.repodir)
        bb.fetch2.check_network_access(d, "repo init -m %s -b %s -u %s://%s%s%s" % (ud.manifest, ud.branch, ud.proto, username, ud.host, ud.path), ud.url)
        runfetchcmd("repo init %s %s -m %s -b %s -u %s://%s%s%s" % (use_depth, use_groups, ud.manifest, ud.branch, ud.proto, username, ud.host, ud.path), d, workdir=ud.repodir)

        bb.fetch2.check_network_access(d, "repo sync %s" % ud.url, ud.url)
        self.sync(ud.repodir, d)

        if ud.directpath != "1":
            scmdata = ud.parm.get("scmdata", "")
            if scmdata == "keep":
                tar_flags = ""
            else:
                tar_flags = "--exclude='.repo' --exclude='.git'"
            runfetchcmd("tar %s -cf - %s | pigz > %s" % (tar_flags, os.path.join(".", "*"), ud.localpath), d, workdir=ud.codir)

    def unpack(self, ud, destdir, d):
        FetchMethod.unpack(self, ud, destdir, d)
        bb.fetch2.check_network_access(d, "repo sync %s" % ud.url, ud.url)
        self.sync(os.path.join(destdir, "repo"), d)

    def supports_srcrev(self):
        return False

    def _build_revision(self, ud, d):
        return ud.manifest

    def _want_sortable_revision(self, ud, d):
        return False
