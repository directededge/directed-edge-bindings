# Copyright (C) 2009 Directed Edge, Inc.
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

try:
    import cStringIO as StringIO
except ImportError:
    import StringIO

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
        """Initializes a handle to a remote Directed Edge database.  Supported
        protocols are HTTP and HTTPS.  You should have been given a user name
        and password when you signed up for a Directed Edge account, which should
        be passed in here."""

        if "DIRECTEDEDGE_HOST" in os.environ.keys():
            host = os.environ["DIRECTEDEDGE_HOST"]
        else:
            host = "webservices.directededge.com"
        self.name = name
        self.resource = Resource("http://%s/api/v1/%s" % (host, name), name, password)

    def import_from_file(self, file_name):
        """If you created an export of your local data using the Exporter class
        from this package you can import it to your Directed Edge account using 
        this method.  Note that all existing data in your database will be
        overwritten."""

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
        """Creates a reference to an item in your Directed Edge database with
        the id given.  If the item already exists, this will become a reference
        to it, if not, it will be created when you call save."""

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

    def links(self, type=""):
        """A dict mapping from link-names to link-weights."""

        self.__read()

        if type not in self.__links:
            return {}
        else:
            return self.__links[type]

    @property
    def link_types(self):
        """Returns the link types that are in use on this item."""
        self.__read()
        return self.__links.keys()

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

    def link_to(self, other, weight=0, type=""):
        """Links this item to another item with the given weight.

        "Other" can be either another item object or the (string) ID of a second
        item.

        The default weight is 0, which indicates an unweighted link.

        Note that items you are linking to must already exist and must have been
        saved before this item is saved or they will be ignored."""

        if weight < 0 or weight > 10:
            raise Exception('Weights must be in the range of zero to 10')
        if isinstance(other, Item):
            other = other.name
        self.__set_link(type, other, weight)
        if other in self.__links_to_remove:
            del self.__links_to_remove[other]

    def unlink_from(self, other, type=""):
        """Removes a link from this item to "other", also may be an Item or string."""

        if isinstance(other, Item):
            other = other.name
        if self.__cached:
            if (type in self.__links) and (other in self.__links[type]):
                del self.__links[type][other]
        else:
            self.__links_to_remove.add(other)

    def weight_for(self, link, type=""):
        """The corresponding weight for the given link, or 0 if there is no weight."""

        self.__read()
        if isinstance(link, Item):
            link = link.name
        return self.__links[type][link]

    def add_tag(self, tag):
        """Adds a tag to this item."""

        self.__tags.add(tag)
        self.__tags_to_remove.discard(tag)

    def remove_tag(self, tag):
        """Removes the given tag from this item if present."""

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
        """Returns true if this item has a property with the given key."""

        self.__read()
        return self.__properties.has_key(key)

    def clear_property(self, key):
        """Removes a property with the given key from the item if present."""

        if not self.__cached:
            self.__properties_to_remove.add(key)
        if self.__properties.has_key(key):
            del self.__properties[key]

    def get_property(self, key):
        """Returns the property with the given key or None if no such property
        exists."""

        self.__read()
        if not self.has_property(key):
            return None
        return self.__properties[key]

    def related(self, tags=[], **params):
        """Returns a list of up to max_results items related to this one, sorted
        by relevance.  Items matching any of the given tags may be returned.

        Note that related is typically used for similar products (or users or
        articles) whereas recommended, below, is used for personalized
        recommendations.
        
        Queries support a number of parameters, e.g.

        - maxResults (integer)
        - excludeLinked (true / false)"""

        params["tags"] = ",".join(Set(tags))
        return self.__read_list(self.__document("related", params), "related")

    def recommended(self, tags=[], **params):
        """Returns a list of up to max_results items recommended for this one,
        sorted by relevance.  Items matching any of the given tags may be
        returned.

        Note that recommended is typically used for personalized recommendations
        (assuming this item is a user), whereas related, above, is used for
        related products, users, etc.

        Queries support a number of parameters, e.g.

        - maxResults (integer)
        - excludeLinked (true / false)"""

        params["tags"] = ",".join(Set(tags))
        if not params.has_key("excludeLinked"):
            params["excludeLinked"] = "true"
        return self.__read_list(self.__document("recommended", params), "recommended")

    def to_xml(self, tags=None, links=None, properties=None, include_document=True):
        """Converts this item to an XML representation.  Only for internal use."""

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

        for type in links:
            for link in links[type]:
                link_element = document.createElement("link")
                item_element.appendChild(link_element)
                if type:
                    link_element.setAttribute("type", type)
                if self.__links[type][link] > 0:
                    link_element.setAttribute("weight", str(links[type][link]))
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

    def __set_link(self, type, target, weight=0):
        if type not in self.__links:
            self.__links[type] = {}
        self.__links[type][target] = weight;

    def __read(self):
        if not self.__cached:
            document = self.__document()

            for node in document.getElementsByTagName("link"):
                name = node.firstChild.data

                type = ""
                if node.attributes.has_key("type"):
                    type = node.attributes["type"].value

                weight = 0
                if node.attributes.has_key("weight"):
                    weight = int(node.attributes["weight"].value)
                if (type not in self.__links) or (name not in self.__links[type]):
                    self.__set_link(type, name, weight)

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
    """A simple tool to export items to an XML file, typically used for exporting
    the contents of a site's local database to the Directed Edge database."""

    def __init__(self, destination):
        """Creates an instance of the exporter.  If destination is a file the
        items will be written to that file; if it is a Database instance,
        the changes will be queued and sent as a batch update to the database
        when finish is called."""

        self.__database = Database("export")

        self.__file = None
        self.__data = StringIO.StringIO()

        if isinstance(destination, str):
            self.__file = open(destination, "w")
        elif isinstance(destination, Database):
            self.__database = destination
        else:
            print "The exporter has to be called on a file name or Database instance."

        self.__write("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n\n")
        self.__write("<directededge version=\"0.1\">\n")

    @property
    def database(self):
        """The database in use for the exporter.  If the Exporter was initialized
        to write to a file this is a pseudo-database that should be used passed
        to the new Items during construction.  If the Exporter was initialized
        pointing to a Database object, this returns that object."""        
        
        return self.__database

    def export(self, item):
        """Adds item to either to the file or queued update list."""

        self.__write(item.to_xml(None, None, None, False) + "\n")

    def finish(self):
        """Finished up writing the export file or, in the case of batch updates
        to a database, transmits the changes."""

        self.__write("</directededge>\n")

        if self.__file:
            self.__file.close()
        else:
            self.database.resource.put(self.__data.getvalue(), "add", { "createMissingLinks" : "true" })

    def __write(self, data):
        if self.__file:
            self.__file.write(data)
        else:
            self.__data.write(data)
