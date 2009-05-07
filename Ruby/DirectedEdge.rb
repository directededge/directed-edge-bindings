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
      host = ENV['DIRECTEDEDGE_HOST']
      if host.nil?
        host = 'webservices.directededge.com'
      end
      @resource =
        RestClient::Resource.new("#{protocol}://#{name}:#{password}@#{host}/api/v1/#{name}")
    end

    def import(file)
      @resource.put(File.read(file), :content_type => 'text/xml')
    end
  end

  # Represents an item in a Directed Edge database

  class Item
    attr_accessor :id

    # Initializes the item with the value id.
    # * Note this does not create the item in the database if it does not exist
    # * See also create

    def initialize(database, id)
      @database = database

      @id = id
      @links = Set.new
      @tags = Set.new
      @properties = {}

      @resource = @database.resource[@id]
      @cached = false
    end

    def ==(other)
      if other.is_a?(Item)
        other.id == id
      else
        other.to_s == id
      end
    end

    # Returns the item's id.

    def name
      @id
    end

    # Creates an item if it does not already exist in the database or overwrites
    # an existing item if one does.

    def create(links=Set.new, tags=Set.new, properties={})
      @links = links
      @tags = tags
      @properties = properties

      # Here we pretend that it's cached since this is now the authoritative
      # copy of the values.

      @cached = true

      save
    end

    def save
      if @cached
        put(complete_document)
      else
        put(complete_document, 'add')
      end
      self
    end

    # Reloads (or loads) the item from the database

    def reload
      document = read_document

      @links = Set.new(list(document, 'link'))
      @tags = Set.new(list(document, 'tags'))
      @properties = {}

      document.elements.each('//property') do |element|
        @properties[element.property('name').value] = element.text
      end
      @cached = true
    end

    def links
      read
      @links
    end

    def tags
      read
      @tags
    end

    def properties
      read
      @properties
    end

    def [](property_name)
      @properties[property_name]
    end

    def []=(property_name, value)
      @properties[property_name] = value
    end

    # Removes an item from the database, including deleting all links to and
    # from this item.

    def destroy
      @resource.delete
    end

    # Creates a link from this item to other.

    def link_to(other, weight=0)
      @links.add(other.to_s)
    end

    # Deletes a link from this item to other.

    def unlink_from(other)
      @links.delete(other.to_s)
    end

    # Adds a tag to this item.

    def add_tag(tag)
      @tags.add(tag)
    end

    # Removes a tag from this item.

    def remove_tag(tag)
      @tags.delete(tag)
    end

    # Returns the list of items related to this one.  Unlike "recommended" this
    # may include items which are directly linked from this item.  If any tags
    # are specified, only items which have one or more of the specified tags
    # will be returned.

    def related(tags=Set.new)
      document = read_document('related?tags=' + tags.to_a.join(','))
      list(document, 'related')
    end

    # Returns the list of items recommended for this item, usually a user.
    # Unlike "related" this does not include items linked from this item.  If
    # any tags are specified, only items which have one or more of the specified
    # tags will be returned.

    def recommended(tags=Set.new)
      document = read_document('recommended?excludeLinked=true&tags=' + tags.to_a.join(','))
      list(document, 'recommended')
    end

    # Returns the id of the item.

    def to_s
      name
    end

    private

    def list(document, element)
      values = []
      document.elements.each("//#{element}") { |v| values.push(v.text) }
      values
    end

    def read
      if !@cached
        begin
          document = read_document
          @links.merge(list(document, 'link'))
          @tags.merge(list(document, 'tags'))

          document.elements.each('//property') do |element|
            name = element.property('name').value
            if !@properties.has_key?(name)
              @properties[name] = element.text
            end
          end
          @cached = true
        rescue
          # Couldn't read 
        end
      end
    end

    def put(document, method='')
      @resource[method].put(document.to_s, :content_type => 'text/xml')
    end

    def read_document(method='')
      REXML::Document.new(@resource[method].get(:accept => 'text/xml'))
    end

    # Creates a document for an entire item including the links, tags and
    # properties.

    def complete_document
      document = REXML::Document.new
      item = setup_document(document)
      @links.each { |link| item.add_element('link').add_text(link.to_s) }
      @tags.each { |tag| item.add_element('tag').add_text(tag.to_s) }
      @properties.each do |key, value|
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
