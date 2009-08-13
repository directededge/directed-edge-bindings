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

class Resource(object):
    """REST resource used in the Directed Edge API"""

    def __init__(self, base_url, user=None, password=None):
        self.__base_url = base_url
        self.__http = httplib2.Http()
        if user:
            self.__http.add_credentials(user, password)

    def path(self, sub="", params={}):
        return self.__base_url + "/" + urllib2.quote(sub) + "?" + urllib.urlencode(params)

    def get(self, sub="", params={}):
        response, content = self.__http.request(self.path(sub, params), "GET")
        if response["status"] != "200":
            return "<directededge/>"
        return content

    def put(self, data, sub="", params={}):
        response, content = self.__http.request(self.path(sub, params), "PUT", data)

class Database(object):
    """A database on the Directed Edge server"""

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

class Item(object):
    """An item in a Directed Edge database

    There are of a collection of methods here for reading and writing to items.
    In general as few reads from the remote database as required will be used,
    specifically items cache all values when any of them are read and writes
    will not be made to the remote database until save() is called."""

    def __init__(self, database, id):
        self.database = database
        self.id = id

        self.__links = {}
        self.__tags = Set()
        self.__properties = {}

        self.__links_to_remove = Set()
        self.__tags_to_remove = Set()
        self.__properties_to_remove = Set()

        self.__cached = False
        
    @property
    def name(self):
        """The ID of the item used to identify it in the database."""

        return self.id

    @property
    def links(self):
        """A dict mapping from link-names to link-weights."""

        self.__read()
        return self.__links

    @property
    def tags(self):
        """The list of tags for the item."""

        self.__read()
        return self.__tags

    @property
    def properties(self):
        """A dict of key-value pair associated with this item."""

        self.__read()
        return self.__properties

    def link_to(self, other, weight=0):
        """Links this item to another item with the given weight.

        "Other" can be either another item object or the (string) ID of a second
        item.

        The default weight is 0, which indicates an unweighted link.

        Note that items you are linking to must already exist and must have been
        saved before this item is saved or they will be ignored."""

        if isinstance(other, Item):
            other = other.name
        self.__links[other] = weight
        if other in self.__links_to_remove:
            del self.__links_to_remove[other]

    def unlink_from(self, other):
        """Removes a link from this item to "other", also may be an Item or string."""

        if isinstance(other, Item):
            other = other.name
        if self.__cached:
            if other in self.__links:
                del self.__links[other]
        else:
            self.__links_to_remove.add(other)

    def weight_for(self, link):
        """The corresponding weight for the given link, or 0 if there is no weight."""

        self.__read()
        if isinstance(link, Item):
            link = link.name
        return self.__links[link]

    def add_tag(self, tag):
        self.__tags.add(tag)
        self.__tags_to_remove.discard(tag)

    def remove_tag(self, tag):
        if self.__cached:
            self.__tags.discard(tag)
        else:
            self.__tags_to_remove.add(tag)

    def __setitem__(self, key, value):
        """May be used to set properties for the item via item["foo"] = "bar"."""

        self.__properties[key] = value
        self.__properties_to_remove.discard(key)

    def __getitem__(self, key):
        """May be used to read properties from the item via item["foo"]."""

        self.__read()
        return self.__properties[key]

    def has_property(self, key):
        self.__read()
        return self.__properties.has_key(key)

    def clear_property(self, key):
        if not self.__cached:
            self.__properties_to_remove.add(key)
        if self.__properties.has_key(key):
            del self.__properties[key]

    def get_property(self, key):
        self.__read()
        if not self.has_property(key):
            return None
        return self.__properties[key]

    def related(self, tags=[], max_results=20):
        """Returns a list of up to max_results related items.

        Items matching any of the given tags may be returned."""

        return self.__read_list(self.__document("related",
                                                { "tags" : ",".join(Set(tags)),
                                                  "maxResults" : max_results }), "related")

    def recommended(self, tags=[], max_results=20):
        """Returns a list of up to max_results recommended items.

        Items matching any of the given tags may be returned."""

        return self.__read_list(self.__document("recommended",
                                                { "excludeLinked" : "true",
                                                  "tags" : ",".join(Set(tags)),
                                                  "maxResults" : max_results }), "recommended")

    def to_xml(self, tags=None, links=None, properties=None, include_document=True):
        if not tags:
            tags = self.__tags
        if not links:
            links = self.__links
        if not properties:
            properties = self.__properties

        implementation = xml.dom.minidom.getDOMImplementation()
        document = implementation.createDocument(None, "directededge", None)
        document.documentElement.setAttribute("version", "0.1")
        item_element = document.createElement("item")
        item_element.setAttribute("id", self.id)

        for tag in tags:
            tag_element = document.createElement("tag")
            item_element.appendChild(tag_element)
            tag_element.appendChild(document.createTextNode(tag))

        for link in links:
            link_element = document.createElement("link")
            item_element.appendChild(link_element)
            if self.__links[link] > 0:
                link_element.setAttribute("weight", str(links[link]))
            link_element.appendChild(document.createTextNode(link))

        for property in properties:
            property_element = document.createElement("property")
            item_element.appendChild(property_element)
            property_element.setAttribute("name", property)
            property_element.appendChild(document.createTextNode(properties[property]))

        document.documentElement.appendChild(item_element)

        if include_document:
            return document.toxml("utf-8")
        else:
            return item_element.toxml("utf-8")

    def save(self):
        """Writes any local changes to the item back to the remote database."""

        if self.__cached:
            self.database.resource.put(self.to_xml(), self.id)
        else:
            if self.__links or self.__tags or self.__properties:
                self.database.resource.put(self.to_xml(), self.id + "/add")
            if self.__links_to_remove or self.__tags_to_remove or self.__properties_to_remove:
                to_dict = lambda list, default: dict(map(lambda x: [x, default], list))
                self.database.resource.put(self.to_xml(self.__tags_to_remove,
                                                       to_dict(self.__links_to_remove, 0),
                                                       to_dict(self.__properties_to_remove, "")),
                                           self.id + "/remove")

                self.__links_to_remove.clear()
                self.__tags_to_remove.clear()
                self.__properties_to_remove.clear()

    def __read(self):
        if not self.__cached:
            document = self.__document()

            for node in document.getElementsByTagName("link"):
                name = node.firstChild.data
                weight = 0
                if node.attributes.has_key("weight"):
                    weight = int(node.attributes["weight"].value)
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

class Exporter(object):
    """A simple tool to export items to an XML file"""
    def __init__(self, file_name):
        self.__database = Database("export")
        self.__file = open(file_name, "w")
        self.__file.write("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n\n")
        self.__file.write("<directededge version=\"0.1\">\n")

    def database(self):
        return self.__database

    def export(self, item):
        self.__file.write(item.to_xml(None, None, None, False) + "\n")

    def finish(self):
        self.__file.write("</directededge>\n")
        self.__file.close()
