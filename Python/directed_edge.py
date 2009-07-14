# Copyright (C) 2009 Directed Edge Ltd.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
# OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
# IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
# NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
# THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import os
import urllib2
import httplib2
import xml.dom.minidom

class Resource:
    def __init__(self, base_url, user=None, password=None):
        self.base_url = base_url
        self.http = httplib2.Http()
        if user:
            self.http.add_credentials(user, password)

    def path(self, sub=""):
        return self.base_url + "/" + urllib2.quote(sub)

    def get(self, sub=""):
        response, content = self.http.request(self.path(sub), "GET")
        return content

    def put(self, data, sub=""):
        response, content = self.http.request(self.path(sub), "PUT", data)

class Database:
    def __init__(self, name, password="", protocol="http"):
        if 'DIRECTEDEDGE_HOST' in os.environ.keys():
            host = os.environ["DIRECTEDEDGE_HOST"]
        else:
            host = "webservices.directededge.com"
        self.name = name
        self.resource = Resource("http://%s/api/v1/%s" % (host, name), name, password)

    def import_from_file(self, file_name):
        file = open(file_name, "r")
        data = file.read()
        
        self.resource.put(data)

class Item:
    def __init__(self, database, id):
        self.database = database
        self.id = id

    def name(self):
        return self.id

    def links(self):
        values = []
        for linkNode in self.__document().getElementsByTagName("link"):
            values.append(linkNode.firstChild.data)
        return values

    def tags(self):
        values = []
        for tagNode in self.__document().getElementsByTagName("tag"):
            values.append(tagNode.firstChild.data)
        return values

    def __document(self):
        return xml.dom.minidom.parseString(self.database.resource.get(self.id))
