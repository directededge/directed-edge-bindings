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

  # Represents a Directed Edge database, simply a collection of items.  Most
  # require a password.  The protocal may either be http (the default) or HTTPS
  # for a secured (but higher latency) connection.

  class Database
    def initialize(name, password='', protocol='http')
      @name = name
      @password = password
      @protocol = protocol

      # @host = 'localhost'
      @host = 'webservices.directededge.com'
    end

    # Queries the database for a given item / method and returns a list of all
    # of all of the items contained in the matching XML element.  If args are
    # specified they are passed on to the query URL.

    def list(item, element, method='', args='')
      values = []
      get(item, method, args).elements.each("//#{element}") { |v| values.push(v.text) }
      values
    end

    # Does an HTTP get to return the XML document that represents the content
    # behind the item / method.  Method can also be nil to just retrieve the
    # item's content.

    def get(item, method, args='')
      begin
        text = RestClient.get(url(item, method, args), :accept => 'text/xml')
        document = REXML::Document.new(text)
      rescue => ex
        puts "Error reading \"#{item}\" from #{@name}."
        document = REXML::Document.new
      end
      document
    end

    # Does a HTTP put on the item / method with the given XML document.  The method
    # can also be nil to simply update the item.

    def put(item, method, document)
      begin
        puts url(item, method), document
        RestClient.put(url(item, method), document.to_s, :content_type => 'text/xml')
      rescue => ex
        puts "Error writing to \"#{item}\" in #{@name} (#{ex.message})"
      end
    end

    # Does an HTTP delete on the item / method.

    def delete(item, method='')
      begin
        RestClient.delete(url(item, method))
      rescue => ex
        puts "Error deleting \"#{item}\" in #{@name} (#{ex.message})"
      end
    end

    private

    # Mangles the given item, method, args and protocol (specified in the
    # constructor) into an address for a Directed Edge resource.

    def url(item, method, args='')
      item = CGI::escape(item)
      password = @password
      if password.length > 0
        password = ":#{password}"
      end
      "#{@protocol}://#{@name}#{password}@#{@host}/api/v1/#{@name}/#{item}/#{method}#{args}"
    end
  end

  # Represents an item in a Directed Edge database

  class Item

    # Initializes the item with the value identifier.
    # * Note this does not create the item in the database if it does not exist
    # * See also create

    def initialize(database, identifier)
      @database = database
      @identifier = identifier
    end

    # Returns the item's identifier.

    def name
      @identifier
    end

    # Creates an item if it does not already exist in the database  If links or
    # tags is set then the item will be created with those default tags.

    def create(links=[], tags=[])
      document = REXML::Document.new
      item = setup_document(document)
      links.each { |link| item.add_element('link').add_text(link) }
      tags.each { |tag| item.add_element('tag').add_text(tag) }
      @database.put(@identifier, '', document)
    end

    # Removes an item from the database, including deleting all links to and
    # from this item.

    def remove
      @database.delete(@identifier)
    end

    # Returns a list of the identifiers that this item is linked to.

    def links
      @database.list(@identifier, 'link')
    end

    # Creates a link from this item to other.

    def link_to(other, weight=0)
      @database.put(@identifier, 'add', item_document('link', other.to_s))
    end

    # Deletes a link from this item to other.

    def unlink_from(other)
      @database.put(@identifier, 'remove', item_document('link', other.to_s))
    end

    # Returns a list of tags on this item.

    def tags
      @database.list(@identifier, 'tag')
    end

    # Adds a tag to this item.

    def add_tag(tag)
      @database.put(@identifier, 'add', item_document('tag', tag.to_s))
    end

    # Removes a tag from this item.

    def remove_tag(tag)
      @database.put(@identifier, 'remove', item_document('tag', tag.to_s))
    end

    # Returns the list of items related to this one.  Unlike "recommended" this
    # may include items which are directly linked from this item.  If any tags
    # are specified, only items which have one or more of the specified tags
    # will be returned.

    def related(tags=[])
      if tags.size > 0
        query = '?tags='
        tags.each { |tag| query += "#{tag}," }
      end
      @database.list(@identifier, 'related', 'related', query)
    end

    # Returns the list of items recommended for this item, usually a user.
    # Unlike "related" this does not include items linked from this item.  If
    # any tags are specified, only items which have one or more of the specified
    # tags will be returned.

    def recommended(tags=[])
      if tags.size > 0
        query = '?tags='
        tags.each { |tag| query += "#{tag}," }
      end
      @database.list(@identifier, 'related', 'related', '?excludeLinked=true')
    end

    # Returns the identifier of the item.

    def to_s
      name
    end

    private

    # Creates a skeleton of an XML document for a given item.

    def item_document(element, value)
      document = REXML::Document.new
      item = setup_document(document)
      item.add_element(element).add_text(value)
      document
    end

    # Sets up an existing XML document with the skeleton Directed Edge elements.

    def setup_document(document)
      directededge = document.add_element('directededge')
      directededge.add_attribute('version', '0.1')
      item = directededge.add_element('item')
      item.add_attribute('id', @identifier)
      item
    end
  end
end
