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

require 'rubygems'
require 'rest_client'
require 'rexml/document'
require 'cgi'

class Hash

  # An extension to normalize tokens and strings of the form foo_bar to strings
  # of fooBar as expected by the REST API.

  def normalize!
    each do |key, value|
      if !key.is_a?(String)
        delete(key)
        key = key.to_s
        store(key, value.to_s)
      end
      if key.match(/_\w/)
        delete(key)
        store(key.gsub(/_\w/) { |s| s[1, 1].upcase }, value.to_s)
      end
    end
    self
  end
end

# The DirectedEdge module contains three classes:
#
# - Database - encapsulation of connection a database hosted by Directed Edge.
# - Exporter - simple mechanism for exporting data from existing data sources.
# - Item - item (user, product, page) in a Directed Edge database.

module DirectedEdge

  # Base class used for Database and Item that has some basic resource
  # grabbing functionality.

  class Resource

    private

    # Reads an item from the database and puts it into an XML document.

    def read_document(method='', params={})
      method << '?' << params.map { |key, value| "#{URI.encode(key)}=#{URI.encode(value.to_s)}" }.join('&')
      REXML::Document.new(@resource[method].get(:accept => 'text/xml'))
    end

    # Returns an array of the elements from the document matching the given
    # element name.

    def list_from_document(document, element)
      values = []
      document.elements.each("//#{element}") { |v| values.push(v.text) }
      values
    end

    # Similar to list_from_document, but instead of a list of items for the given
    # element returns a hash of key-value pairs (attributes), e.g.:
    #
    # 'item1' => { 'foo' => 'bar' }

    def property_hash_from_document(document, element)
      values = {}
      document.elements.each("//#{element}") do |e|
        values[e.text] = {}
        e.attributes.each_attribute { |a| values[e.text][a.name] = a.value }
      end
      values
    end

    # Returns a hash of the elements from the document matching the given
    # element name.  If the specified attribute is present, its value will
    # be assigned to the hash, otherwise the default value given will be
    # used.

    def hash_from_document(document, element, attribute, default=0)
      values = {}
      document.elements.each("//#{element}") do |v|
        value = v.attribute(attribute).to_s || default
        if value.empty?
          values[v.text] = default
        elsif value.to_i.to_s == value.to_s
          values[v.text] = value.to_i
        else
          values[v.text] = value.to_s
        end
      end
      values
    end
  end

  # A Database is an encapsulation of a database being accessed via the Directed
  # Edge web-services API.  You can request database creation by visiting
  # http://www.directededge.com and will recieve a user name and password which
  # are then used to connect to your DirectedEdge::Database instance.
  #
  # Usually when getting started with a DirectedEdge database, users would like to
  # import some pre-existing data, usually from their web application's database.
  # The Database class has an import method which can be used to import data using
  # Directed Edge's XML format.  Files formatted in that way may be created with
  # the Exporter.
  #
  # A database is typically instantiated via:
  #
  #   database = DirectedEdge::Database.new('mydatabase', 'mypassword')

  class Database < Resource

    # The name of the database.

    attr_reader :name

    # The REST resource used for connecting to the database.

    attr_reader :resource

    # Creates a connection to a Directed Edge database.  The name and password
    # should have been provided when the account was created.  The protocol
    # parameter is optional and may be <tt>http</tt> or <tt>https</tt>.
    # <tt>http</tt> is used by default as it is somewhat lower latency.

    def initialize(name, password='', protocol='http')
      @name = name
      host = ENV['DIRECTEDEDGE_HOST'] || 'webservices.directededge.com'
      @resource =
        RestClient::Resource.new("#{protocol}://#{name}:#{password}@#{host}/api/v1/#{name}")
    end

    # Imports a Directed Edge XML file to the database.
    #
    # See http://developer.directededge.com for more information on the XML format or the
    # Exporter for help on creating a file for importing.

    def import(file_name)
      @resource.put(File.read(file_name), :content_type => 'text/xml')
    end

    # Returns a set of recommendations for the set of items that is passed in in
    # aggregate, commonly used to do recommendations for a basket of items.

    def group_related(items=Set.new, tags=Set.new, params={})
      (!items.is_a?(Array) || items.size < 1) and return []
      params['items'] = items.to_a.join(',')
      params['tags'] = tags.to_a.join(',')
      params['union'] = true
      list_from_document(read_document('related', params), 'related')
    end
  end

  # A very simple class for creating Directed Edge XML files or doing batch
  # updates to a database.  This can be done for example with:
  #
  #   exporter = DirectedEdge::Exporter.new('mydatabase.xml')
  #   item = DirectedEdge::Item.new(exporter.database, 'product_1')
  #   item.add_tag('product')
  #   exporter.export(item)
  #   exporter.finish
  #
  # <tt>mydatabase.xml</tt> now contains:
  #
  #   <?xml version="1.0" encoding="UTF-8"?>
  #   <directededge version="0.1">
  #   <item id='product_1'><tag>product</tag></item>
  #   </directededge>
  #
  # Which can then be imported to a database on the server with:
  #
  #   database = DirectedEdge::Database.new('mydatabase', 'mypassword')
  #   database.import('mydatabase.xml')
  #
  # Alternatively, had the first line been:
  #
  #   exporter = DirectedEdge::Exporter.new(some_database_object)
  #
  # Then newly created / modfied objects that on which export was called would be
  # queued for a batch update to the database later.
  #
  # Items may also be exported from existing databases.

  class Exporter

    # Provides a dummy database for use when creating new items to be exported.

    attr_reader :database

    # Begins exporting a collection of items to the given destination.  If the
    # destination is a file existing contents will be overwritten.  If the
    # destination is an existing database object, updates will be queued until
    # finish is called, at which point they will be uploaded to the webservices
    # in batch.

    def initialize(destination)
      if destination.is_a?(String)
        @database = Database.new('exporter')
        @file = File.new(destination, 'w')
      elsif destination.is_a?(Database)
        @database = destination
        @data = ""
      else
        raise TypeError.new("Exporter must be passed a file name or database object.")
      end

      write("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n\n")
      write("<directededge version=\"0.1\">\n")
    end

    # Exports the given item to the file passed to the constructor.

    def export(item)
      write("#{item.to_xml}\n")
    end

    # Writes a closing XML element to the document and closes the file.

    def finish
      write("</directededge>\n")
      if !@file.nil?
        @file.close
      else
        @database.resource['add'].put(@data)
      end
    end

    private

    def write(data)
      if !@file.nil?
        @file.write(data)
      else
        @data += data
      end
    end
  end

  # Represents an item in a Directed Edge database.  Items can be products, pages
  # or users, for instance.  Usually items groups are differentiated from one
  # another by a set of tags that are provided.
  #
  # For instance, a user in the Directed Edge database could be modeled as:
  #
  #   user = DirectedEdge::Item.new(database, 'user_1')
  #   user.add_tag('user')
  #   user.save
  #
  # Similarly a product could be:
  #
  #   product = DirectedEdge::Item.new(database, 'product_1')
  #   product.add_tag('product')
  #   product['price'] = '$42'
  #   product.save
  #
  # Note here that items have tags and properties.  Tags are a free-form set of
  # text identifiers that can be associated with an item, e.g. "user", "product",
  # "page", "science fiction", etc.
  #
  # Properties are a set of key-value pairs associated with the item.  For example,
  # <tt>product['price'] = '$42'</tt>, or <tt>user['first name'] = 'Bob'</tt>.
  #
  # If we wanted to link the user to the product, for instance, indicating that the
  # user had purchased the product we can use:
  #
  #   user.link_to(product)
  #   user.save

  class Item < Resource

    # The unique item identifier used by the database and specified in the item's
    # constructor.

    attr_reader :id

    # Creates a handle to an item in the DirectedEdge database which may be
    # manipulated locally and then saved back to the database by calling save.

    def initialize(database, id)
      @database = database

      @id = id
      @links = {}
      @tags = Set.new
      @properties = {}

      @links_to_remove = Set.new
      @tags_to_remove = Set.new
      @properties_to_remove = Set.new

      @resource = @database.resource[URI.escape(@id)]
      @cached = false
    end

    # Returns true if the other item is the same.  The item given can either be
    # a string or an item object.

    def ==(other)
      if other.is_a?(Item)
        other.id == id
      else
        other.to_s == id
      end
    end

    # Returns the item's ID.

    def name
      @id
    end

    # Creates an item if it does not already exist in the database or overwrites
    # an existing item if one does.

    def create(links={}, tags=Set.new, properties={})
      @links = links
      @tags = tags
      @properties = properties

      # Here we pretend that it's cached since this is now the authoritative
      # copy of the values.

      @cached = true
      save
    end

    # Writes all changes to links, tags and properties back to the database and
    # returns this item.

    def save
      if @cached
        put(complete_document)
      else

        # The web services API allows to add or remove things incrementally.
        # Since we're not in the cached case, let's check to see which action(s)
        # are appropriate.

        put(complete_document, 'add')

        if !@links_to_remove.empty? || !@tags_to_remove.empty? || !@properties_to_remove.empty?
          put(removal_document, 'remove')
          @links_to_remove.clear
          @tags_to_remove.clear
          @properties_to_remove.clear
        end
      end
      self
    end

    # Reloads (or loads) the item from the database.  Any unsaved changes will
    # will be discarded.

    def reload
      document = read_document

      @links = hash_from_document(document, 'link', 'weight')
      @tags = Set.new(list_from_document(document, 'tag'))
      @properties = {}

      @links_to_remove.clear
      @tags_to_remove.clear
      @properties_to_remove.clear

      document.elements.each('//property') do |element|
        @properties[element.attribute('name').value] = element.text
      end
      @cached = true
    end

    # Returns a set of items that are linked to from this item.

    def links
      read
      @links
    end

    # Returns a set containing all of this item's tags.

    def tags
      read
      @tags
    end

    # Returns a hash of all of this item's properties.

    def properties
      read
      @properties
    end

    # Returns the property for the name specified.

    def [](property_name)
      read
      @properties[property_name]
    end

    # Assigns value to the given property_name.
    #
    # This will not be written back to the database until save is called.

    def []=(property_name, value)
      @properties_to_remove.delete(property_name)
      @properties[property_name] = value
    end

    # Remove the given property_name.

    def clear_property(property_name)
      if !@cached
        @properties_to_remove.add(property_name)
      end
      @properties.delete(property_name)
    end

    # Removes an item from the database, including deleting all links to and
    # from this item.

    def destroy
      @resource.delete
    end

    # Creates a link from this item to other.
    #
    # Weighted links are typically used to encode ratings.  For instance, if
    # a user has rated a given product that can be specified via:
    #
    #   user = DirectedEdge::Item(database, 'user_1')
    #   product = DirectedEdge::Item(database, 'product_1') # preexisting item
    #   user.link_to(product, 5)
    #   user.save
    #
    # If no link is specified then a tradtional, unweighted link will be
    # created.  This is typical to, for instance, incidate a purchase or click
    # from a user to a page or item.
    #
    # Weights may be in the range of 1 to 10.
    #
    # Note that 'other' must exist in the database or must be saved before this
    # item is saved.  Otherwise the link will be ignored as the engine tries
    # to detect 'broken' links that do not terminate at a valid item.

    def link_to(other, weight=0)
      if weight < 0 || weight > 10
        raise RangeError
      end
      @links_to_remove.delete(other)
      @links[other.to_s] = weight
    end

    # Deletes a link from this item to other.
    #
    # The changes will not be reflected in the database until save is called.

    def unlink_from(other)
      if !@cached
        @links_to_remove.add(other.to_s)
      end
      @links.delete(other.to_s)
    end

    # If there is a link for "other" then it returns the weight for the given
    # item.  Zero indicates that no weight is assigned.

    def weight_for(other)
      read
      @links[other.to_s]
    end

    # Adds a tag to this item.
    #
    # The changes will not be reflected in the database until save is called.

    def add_tag(tag)
      @tags_to_remove.delete(tag)
      @tags.add(tag)
    end

    # Removes a tag from this item.
    #
    # The changes will not be reflected in the database until save is called.

    def remove_tag(tag)
      if !@cached
        @tags_to_remove.add(tag)
      end
      @tags.delete(tag)
    end

    # Returns the list of items related to this one.  Unlike "recommended" this
    # may include items which are directly linked from this item.  If any tags
    # are specified, only items which have one or more of the specified tags
    # will be returned.
    #
    # Parameters that may be passed in include:
    # - :exclude_linked (true / false)
    # - :max_results (integer)
    #
    # This will not reflect any unsaved changes to items.

    def related(tags=Set.new, params={})
      params.normalize!
      params['tags'] = tags.to_a.join(',')
      if params['includeProperties'] == 'true'
        property_hash_from_document(read_document('related', params), 'related')
      else
        list_from_document(read_document('related', params), 'related')
      end
    end

    # Returns the list of items recommended for this item, usually a user.
    # Unlike "related" this does not include items linked from this item.  If
    # any tags are specified, only items which have one or more of the specified
    # tags will be returned.
    #
    # Parameters that may be passed in include:
    # - :exclude_linked (true / false)
    # - :max_results (integer)
    #
    # This will not reflect any unsaved changes to items.

    def recommended(tags=Set.new, params={})
      params.normalize!
      params['tags'] = tags.to_a.join(',')
      params.key?('excludeLinked') || params['excludeLinked'] = 'true'
      if params['includeProperties'] == 'true'
        property_hash_from_document(read_document('recommended', params), 'recommended')
      else
        list_from_document(read_document('recommended', params), 'recommended')
      end
    end

    # Returns the ID of the item.

    def to_s
      @id
    end

    # Returns an XML representation of the item as a string not including the
    # usual document regalia, e.g. starting with <item> (used for exporting the
    # item to a file)

    def to_xml
      insert_item(REXML::Document.new).to_s
    end

    private

    # Reads the tags / links / properties from the server if they are not
    # already cached.

    def read
      if !@cached
        begin
          document = read_document
          @links.merge!(hash_from_document(document, 'link', 'weight'))
          @tags.merge(list_from_document(document, 'tag'))

          document.elements.each('//property') do |element|
            name = element.attribute('name').value
            if !@properties.has_key?(name)
              @properties[name] = element.text
            end
          end

          @links_to_remove.each { |link| @links.delete(link) }
          @tags_to_remove.each { |tag| @tags.delete(tag) }
          @properties_to_remove.each { |property| @properties.delete(property) }

          @links_to_remove.clear
          @tags_to_remove.clear
          @properties_to_remove.clear

          @cached = true
        rescue
          puts "Couldn't read \"#{@id}\" from the database."
        end
      end
    end

    # Uploads the changes to the Directed Edge database.  The optional method
    # parameter may be used for either add or remove which do only incremental
    # updates to the item.

    def put(document, method='')
      @resource[method].put(document.to_s, :content_type => 'text/xml')
    end

    # Creates a document for an entire item including the links, tags and
    # properties.

    def complete_document
      document = REXML::Document.new
      insert_item(document)
    end

    def removal_document
      item = setup_document(REXML::Document.new)
      @links_to_remove.each { |link| item.add_element('link').add_text(link.to_s) }
      @tags_to_remove.each { |tag| item.add_element('tag').add_text(tag.to_s) }
      @properties_to_remove.each do |property|
        item.add_element('property').add_attribute('name', property.to_s)
      end
      item
    end

    def insert_item(document)
      item = setup_document(document)
      @links.each do |link, weight|
        element = item.add_element('link')
        if weight != 0
          element.add_attribute('weight', weight.to_s)
        end
        element.add_text(link.to_s)
      end
      @tags.each { |tag| item.add_element('tag').add_text(tag.to_s) }
      @properties.each do |key, value|
        property = item.add_element('property')
        property.add_attribute('name', key.to_s)
        property.add_text(value.to_s)
      end
      item
    end

    # Creates a skeleton of an XML document for a given item.

    def item_document(element, value)
      document = REXML::Document.new
      item = setup_document(document)
      item.add_element(element).add_text(value.to_s)
      document
    end

    # Sets up an existing XML document with the skeleton Directed Edge elements.

    def setup_document(document)
      directededge = document.add_element('directededge')
      directededge.add_attribute('version', '0.1')
      item = directededge.add_element('item')
      item.add_attribute('id', @id.to_s)
      item
    end
  end
end
