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

require 'rubygems'
require 'rest_client'
require 'rexml/document'
require 'cgi'

module DirectedEdge

  class ItemNotFound < StandardError ; end
  class ConnectionError < StandardError ; end
  class AuthenticationError < StandardError ; end

  # Represents a Directed Edge database, simply a collection of items.  Most
  # require a password.  The protocal may either be http (the default) or HTTPS
  # for a secured (but higher latency) connection.

  class Database
    attr_accessor :name, :resource

    def initialize(name, password='', protocol='http')
      @name = name
      @password = password
      @protocol = protocol

      @host = ENV['DIRECTEDEDGE_HOST']
      if @host.nil?
        @host = 'webservices.directededge.com'
      end
      @resource =
        RestClient::Resource.new("#{@protocol}://#{@name}:#{@password}@#{@host}/api/v1/#{@name}")
    end

    def import(file)
      @resource.put(File.read(file), :content_type => 'text/xml')
    end
  end

  # Represents an item in a Directed Edge database

  class Record
    attr_accessor :id, :resource

    # Initializes the item with the value id.
    # * Note this does not create the item in the database if it does not exist
    # * See also create

    def initialize(database, id)
      @database = database
      @id = id
      @resource = @database.resource[@id]
    end

    # Returns the item's id.

    def name
      @id
    end

    # Creates an item if it does not already exist in the database or overwrites
    # an existing item if one does.

    def create(links=[], tags=[], properties={})
      put(complete_document(links, tags, properties))
    end

    # Creates an item if it does not already exist in the database or adds the
    # links, tags and properties to an existing item if one does.

    def add(links=[], tags=[], properties={})
      put(complete_document(links, tags, properties), 'add')
    end

    # Removes an item from the database, including deleting all links to and
    # from this item.

    def remove
      @resource.delete
    end

    # Returns a list of the ids that this item is linked to.

    def links
      list('link')
    end

    # Returns a list of the ids that this item is referenced from (the
    # items that link to this item).

    def references
      list('reference', '?showReferences=true')
    end

    # Creates a link from this item to other.

    def link_to(other, weight=0)
      put(item_document('link', other.to_s), 'add')
    end

    # Deletes a link from this item to other.

    def unlink_from(other)
      put(item_document('link', other.to_s), 'remove')
    end

    # Returns a list of tags on this item.

    def tags
      list('tag')
    end

    # Adds a tag to this item.

    def add_tag(tag)
      put(item_document('tag', tag.to_s), 'add')
    end

    # Removes a tag from this item.

    def remove_tag(tag)
      put(item_document('tag', tag.to_s), 'remove')
    end

    # Returns a hash of all of the properties for the item.

    def properties
      props = {}
      text = @resource.get(:accept => 'text/xml')
      REXML::Document.new(text).elements.each('//property') do |element|
        props[element.attribute('name').value] = element.text
      end
      props
    end

    # Returns the value of the given property if any.

    def property(property)
      properties[property]
    end

    def set_property(name, value)
      add([], [], { name => value })
    end

    # Returns the list of items related to this one.  Unlike "recommended" this
    # may include items which are directly linked from this item.  If any tags
    # are specified, only items which have one or more of the specified tags
    # will be returned.

    def related(tags=[])
      list('related', 'related?tags=' + tags.join(','))
    end

    # Returns the list of items recommended for this item, usually a user.
    # Unlike "related" this does not include items linked from this item.  If
    # any tags are specified, only items which have one or more of the specified
    # tags will be returned.

    def recommended(tags=[])
      list('recommended', 'recommended?excludeLinked=true&tags=' + tags.join(','))
    end

    # Returns the id of the item.

    def to_s
      name
    end

    private

    # Queries the database for a given item / method and returns a list of all
    # of all of the items contained in the matching XML element.

    def list(from_element, method='')
      values = []
      document = REXML::Document.new(@resource[method].get(:accept => 'text/xml'))
      if document.nil?
        values = nil
      else
          document.elements.each("//#{from_element}") { |v| values.push(v.text) }
      end
      values
    end

    def put(document, method='')
      @resource[method].put(document.to_s, :content_type => 'text/xml')
    end

    # Creates a document for an entire item including the links, tags and
    # properties.

    def complete_document(links, tags, properties)
      document = REXML::Document.new
      item = setup_document(document)
      links.each { |link| item.add_element('link').add_text(link.to_s) }
      tags.each { |tag| item.add_element('tag').add_text(tag.to_s) }
      properties.each do |key, value|
        property = item.add_element('property')
        property.add_attribute('name', key.to_s)
        property.add_text(value.to_s)
      end
      document
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
