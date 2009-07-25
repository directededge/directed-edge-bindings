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
import urllib
import urllib2
import httplib2
import xml.dom.minidom
from sets import Set

class Resource:
    def __init__(self, base_url, user=None, password=None):
        self.__base_url = base_url
        self.__http = httplib2.Http()
        if user:
            self.__http.add_credentials(user, password)

    def path(self, sub="", params={}):
        return self.__base_url + "/" + urllib2.quote(sub) + "?" + urllib.urlencode(params)

    def get(self, sub="", params={}):
        response, content = self.__http.request(self.path(sub, params), "GET")
        return content

    def put(self, data, sub="", params={}):
        response, content = self.__http.request(self.path(sub, params), "PUT", data)

class Database:
    def __init__(self, name, password="", protocol="http"):
        if "DIRECTEDEDGE_HOST" in os.environ.keys():
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

        self.__links = {}
        self.__tags = Set()
        self.__properties = {}

        self.__link_to_remove = Set()
        self.__tags_to_remove = Set()
        self.__properties_to_remove = Set()

        self.__cached = False
        
    def name(self):
        return self.id

    def links(self):
        self.__read()
        return self.__links

    def tags(self):
        self.__read()
        return self.__tags

    def properties(self):
        self.__read()
        return self.__properties

    def related(self, tags=[], max_results=20):
        return self.__read_list(self.__document("related",
                                                { "tags" : ",".join(Set(tags)),
                                                  "maxResults" : max_results }), "related")

    def recommended(self, tags=[], max_results=20):
        return self.__read_list(self.__document("recommended",
                                                { "excludeLinked" : "true",
                                                  "tags" : ",".join(Set(tags)),
                                                  "maxResults" : max_results }), "recommended")

    def __read(self):
        if not self.__cached:
            document = self.__document()

            for node in document.getElementsByTagName("link"):
                name = node.firstChild.data
                weight = 0
                if node.attributes.has_key("weight"):
                    weight = node.attributes["weight"].value
                if name not in self.__links:
                    self.__links[name] = weight

            self.__tags.update(self.__read_list(document, "tag"))

            for node in document.getElementsByTagName("property"):
                name = node.attributes["name"].value
                if name not in self.__properties:
                    self.__properties[name] = node.firstChild.data

            self.__cached = True

    def __document(self, sub="", params={}):
        content = self.database.resource.get(self.id + "/" + sub, params)
        return xml.dom.minidom.parseString(content)

    def __read_list(self, document, element_name):
        values = []
        for node in document.getElementsByTagName(element_name):
            values.append(node.firstChild.data)
        return values
