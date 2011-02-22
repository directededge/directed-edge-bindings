# Copyright (C) 2009-2010 Directed Edge, Inc.
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

# The DirectedEdge module contains three classes:
#
# - Database - encapsulation of connection a database hosted by Directed Edge.
# - Exporter - simple mechanism for exporting data from existing data sources.
# - Item - item (user, product, page) in a Directed Edge database.

module DirectedEdge

  # @private

  class InsertOrderHash < Hash

    def []=(key, value)
      store(key, value)
      @insert_order = [] if @insert_order.nil?
      @insert_order.delete(key) if @insert_order.include?(key)
      @insert_order.push(key)
    end

    def insert_order_each
      @insert_order.each { |key| yield key, fetch(key) } unless @insert_order.nil?
    end
  end

  # @private

  class CollectionHash < Hash
    def initialize(type)
      @type = type
    end
    def [](key)
      self[key] = @type.new unless include? key
      super(key)
    end
    def each
      super { |key, value| yield(key, value) unless value.empty? }
    end
    def empty?
      each { |key, value| return false } ; true
    end
  end

  # @private

  class Resource

    private

    def initialize(rest_resource)
      @resource = rest_resource
    end

    # Reads an item from the database and puts it into an XML document.

    def read_document(method='', params={})
      method << '?' << params.map { |key, value| "#{URI.encode(key)}=#{URI.encode(value)}" }.join('&')
      REXML::Document.new(@resource[method].get(:accept => 'text/xml').to_s)
    end

    # @return [Array] The elements from the document matching the given
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
      values = InsertOrderHash.new
      document.elements.each("//#{element}") do |e|
        values[e.text] = {}
        e.attributes.each_attribute { |a| values[e.text][a.name] = a.value }
      end
      values.each { |k, v| v['tags'] = v['tags'].split(',') if v.include?('tags') }
      values
    end

    # Normalizes the parameters in an argument hash to a standard form
    # so that they can be passed off to the web services API -- e.g.
    # :foo_bar to 'fooBar'

    def normalize_params!(hash)
      hash.each do |key, value|
        if !key.is_a?(String)
          hash.delete(key)
          key = key.to_s
          hash.store(key, value.to_s)
        end
        if key.match(/_\w/)
          hash.delete(key)
          hash.store(key.gsub(/_\w/) { |s| s[1, 1].upcase }, value.to_s)
        elsif !value.is_a?(String)
          hash.store(key, value.to_s)
        end
      end
      hash
    end

    def with_properties?(params)
      params['includeProperties'] == 'true' || params['includeTags'] == 'true'
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
    # should have been provided when the account was created.
    #
    # @param [String] name User name given when the Directed Edge account was
    #  created.
    # @param [String] password Password given when the Directed Edge account was
    #  created.
    # @param [String] protocol The protocol to connect to the Directed Edge
    #  webservices with.
    #
    # @return [DirectedEdge::Item]

    def initialize(name, password='', protocol='http', options = {})
      @name = name
      host = options[:host] || ENV['DIRECTEDEDGE_HOST'] || 'webservices.directededge.com'
      url = "#{protocol}://#{name}:#{password}@#{host}/api/v1/#{name}"

      options[:timeout] ||= 10

      super(RestClient::Resource.new(url, options))
    end

    # Imports a Directed Edge XML file to the database.
    #
    # @see Exporter
    # 
    # @see {Developer site}[http://developer.directededge.com/] for more information
    # on the XML format.

    def import(file_name)
      @resource.put(File.read(file_name), :content_type => 'text/xml')
    end

    # @return [Array] A set of recommendations for the set of items that is passed in in
    # aggregate, commonly used to do recommendations for a basket of items.
    #
    # @param [Array] items List of items to base the recommendations on, e.g. all of the
    #  items in the basket.
    #
    # The tags and params parameters are equivalent to those with the normal Item#related
    # call.
    #
    # @see Item#related

    def group_related(items=Set.new, tags=Set.new, params={})
      if !items.is_a?(Array) || items.size < 1
        return with_properties?(params) ? InsertOrderHash.new : []
      end
      params['items'] = items.to_a.join(',')
      params['tags'] = tags.to_a.join(',')
      params['union'] = true
      normalize_params!(params)
      if params['includeProperties'] == 'true'
        property_hash_from_document(read_document('related', params), 'related')
      else
        list_from_document(read_document('related', params), 'related')
      end
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
    #
    # @return [Exporter]

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
      super(database.resource[URI.escape(id, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))])

      @database = database
      @id = id
      @links = CollectionHash.new(Hash)
      @tags = Set.new
      @preselected = []
      @blacklisted = Set.new
      @properties = {}

      @links_to_remove = CollectionHash.new(Set)
      @tags_to_remove = Set.new
      @preselected_to_remove = Set.new
      @blacklisted_to_remove = Set.new
      @properties_to_remove = Set.new
      @cached = false
    end

    # @return [Boolean] True if the other item has the same ID.  The item given
    # can either be a string or an item object.

    def ==(other)
      if other.is_a?(Item)
        other.id == id
      else
        other.to_s == id
      end
    end

    # @return [String] The item's ID

    def name
      @id
    end

    # @deprecated Use new / save instead.

    def create(links={}, tags=Set.new, properties={})
      warn 'DirectedEdge::Item::create has been deprecated. Use new / save instead.'
      @links[''] = links
      @tags = tags
      @properties = properties

      # Here we pretend that it's cached since this is now the authoritative
      # copy of the values.

      @cached = true
      save
    end

    # Writes all changes to links, tags and properties back to the database and
    # returns this item.
    #
    # @return [Item]

    def save(options={})
      if options[:overwrite] || @cached
        put(complete_document)
      else

        # The web services API allows to add or remove things incrementally.
        # Since we're not in the cached case, let's check to see which action(s)
        # are appropriate.

        put(complete_document, 'add')

        ### CHECKING LINKS_TO_REMOVE.EMPTY? ISN'T CORRECT ANYMORE

        if !@links_to_remove.empty? ||
            !@tags_to_remove.empty? ||
            !@preselected_to_remove.empty? ||
            !@blacklisted_to_remove.empty? ||
            !@properties_to_remove.empty?
          put(removal_document, 'remove')
          @links_to_remove.clear
          @tags_to_remove.clear
          @properties_to_remove.clear
          @preselected_to_remove.clear
          @blacklisted_to_remove.clear
        end
      end
      self
    end

    # Reloads (or loads) the item from the database.  Any unsaved changes will
    # will be discarded.
    #
    # @return [Item]

    def reload
      @links.clear
      @tags.clear
      @preselected.clear
      @blacklisted.clear
      @properties.clear

      @links_to_remove.clear
      @tags_to_remove.clear
      @preselected_to_remove.clear
      @blacklisted_to_remove.clear
      @properties_to_remove.clear

      @cached = false
      read
      self
    end

    # @return [Set] Items that are linked to from this item.
    #
    # @param [String] type Only links for the specified link-type will be
    #  returned.

    def links(type='')
      read
      @links[type.to_s]
    end

    # @return [Set] The tags for this item.

    def tags
      read
      @tags
    end

    # An ordered list of preselected recommendations for this item.
    #
    # @return [Array] The preselected recommendations for this item.

    def preselected
      read
      @preselected
    end

    # An ordered list of blacklisted recommendations for this item.
    #
    # @return [Array] The items blacklisted from being recommended for this item.

    def blacklisted
      read
      @blacklisted
    end

    # All properties for this item.
    #
    # @return [Hash] All of the properties for this item.

    def properties
      read
      @properties
    end

    # Fetches properties of the item.
    #
    # @return [String] The property for this item.

    def [](property_name)
      read
      @properties[property_name]
    end

    # Assigns value to the given property_name.
    #
    # This will not be written back to the database until save is called.
    #
    # @return [Item]

    def []=(property_name, value)
      @properties_to_remove.delete(property_name)
      @properties[property_name] = value
      self
    end

    # Remove the given property_name.
    #
    # @return [Item]

    def clear_property(property_name)
      @properties_to_remove.add(property_name) unless @cached
      @properties.delete(property_name)
      self
    end

    # Removes an item from the database, including deleting all links to and
    # from this item.

    def destroy
      @resource.delete
      nil
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
    # @param [String] other An identifier (or Item instance) for an item to be linked
    #  to.
    # @param [Integer] weight A weight in the range of 1 to 10 for this link.  If not
    #  specified (which is fine for most situations) an unweighted link will be
    #  created.
    # @param [String] type The link type to be used for this connection, or, the
    #  default untyped link.  This could be, for example, *purchase* or *rating*.
    #
    # Note that 'other' must exist in the database or must be saved before this
    # item is saved.  Otherwise the link will be ignored as the engine tries
    # to detect 'broken' links that do not terminate at a valid item.
    # 
    # @return [String] The item ID just linked to

    def link_to(other, weight=0, type='')
      raise RangeError if (weight < 0 || weight > 10)
      @links_to_remove[type.to_s].delete(other)
      @links[type.to_s][other.to_s] = weight
      other
    end

    # Removes a relationship from this item to another item.
    #
    # The changes will not be reflected in the database until save is called.
    #
    # @param [String] other The ID (or Item instance) for an object to be
    #  unlinked.
    # @return [String] The item ID just unlinked from.
    # @see Item#link_to

    def unlink_from(other, type='')
      @links_to_remove[type.to_s].add(other.to_s) unless @cached
      @links[type.to_s].delete(other.to_s)
      other
    end

    # If there is a link for "other" then it returns the weight for the given
    # item.  Zero indicates that no weight is assigned.
    #
    # @param [String] other The item being queried for.
    # @param [String] type The link type of the relationship.
    #
    # @return [Integer] The weight for a link from this item to the specified
    #  item, or nil if not found.

    def weight_for(other, type='')
      read
      @links[type.to_s][other.to_s]
    end

    # Adds a tag to this item.
    #
    # @param [String] tag The tag to be added to this item's tag set.
    # @return [String] The tag just added.
    #
    # The changes will not be reflected in the database until save is called.

    def add_tag(tag)
      @tags_to_remove.delete(tag)
      @tags.add(tag)
      tag
    end

    # Removes a tag from this item.
    #
    # @param [String] tag The tag to be removed from this item's set of tags.
    # @return [String] The tag just removed.
    #
    # The changes will not be reflected in the database until save is called.

    def remove_tag(tag)
      @tags_to_remove.add(tag) unless @cached
      @tags.delete(tag)
      tag
    end

    # Adds a hand-picked recommendation for this item.
    #
    # Note that preselected recommendations are weighted by the order that they
    # are added, i.e. the first preselected item added will be the first one
    # shown.
    #
    # @param [String] item The ID (or an Item instance) of the item that should
    #  be always returned as a recommendation for this item.
    # @return [String] The ID just added.

    def add_preselected(item)
      @preselected_to_remove.delete(item.to_s)
      @preselected.push(item.to_s)
      item
    end

    # Removes a hand-picked recommendation for this item.
    #
    # @param [String] item The ID (or an Item instance) of the item that should
    #  be removed from the preselected list.
    # @return [String] The ID just removed.
    #
    # @see Item#add_preselected

    def remove_preselected(item)
      @preselected_to_remove.add(item.to_s) unless @cached
      @preselected.delete(item.to_s)
      item
    end

    # Adds a blacklisted item that should never be shown as recommended for this
    # item.
    #
    # @param [String] item The ID (or an Item instance) of the item that should
    #  be blacklisted.
    # @return [String] The ID just blacklisted.

    def add_blacklisted(item)
      @blacklisted_to_remove.delete(item.to_s)
      @blacklisted.add(item.to_s)
      item
    end

    # Removes a blacklisted item.
    #
    # @param [String] item The ID (or an Item instance) of the item that should
    #  be removed from the blacklist.
    # @return [String] The ID just delisted.
    #
    # @see Item::add_blacklisted

    def remove_blacklisted(item)
      @blacklisted_to_remove.add(item.to_s) unless @cached
      @blacklisted.delete(item.to_s)
      item
    end

    # related and recommended are the two main methods for querying for
    # recommendations with the Directed Edge API.  Related is for *similar*
    # items, e.g. "products like this product", whereas recommended is for
    # personalized recommendations, i.e. "We think you'd like..."
    #
    # @return [Array] List of item IDs related to this one with the most closely
    # related items first.
    # 
    # @param [Set] tags Only items which have at least one of the provided tags
    # will be returned.
    #
    # @param [Hash] options A set of options which are passed directly on to
    # the web services API in the query string.
    #
    # @option params [Boolean] :exclude_linked (false)
    #  Exclude items which are linked directly from this item.
    # @option params [Integer] :max_results (20)
    #  Only returns up to :max_results items.
    # @option params [Integer] :link_type_weight (1)
    #  Here link_type should be replace with one of the actual link types in
    #  use in your database, i.e. :purchase_weight and specifies how strongly
    #  links of that type should be weighted related to other link types.  For
    #  Instance if you wanted 20% ratings and 80% purchases you would specify:
    #  :purchases_weight => 8, :ratings_weight => 2
    #
    # This will not reflect any unsaved changes to items.
    #
    # @see Item#recommended

    def related(tags=Set.new, params={})
      normalize_params!(params)
      params['tags'] = tags.to_a.join(',')
      if with_properties?(params)
        property_hash_from_document(read_document('related', params), 'related')
      else
        list_from_document(read_document('related', params), 'related')
      end
    end

    # related and recommended are the two main methods for querying for
    # recommendations with the Directed Edge API.  Related is for *similar*
    # items, e.g. "products like this product", whereas recommended is for
    # personalized recommendations, i.e. "We think you'd like..."
    #
    # @return [Array] List of item IDs recommeded for this item with the most
    # strongly recommended items first.
    # 
    # @param [Set] tags Only items which have at least one of the provided tags
    # will be returned.
    #
    # @param [Hash] options A set of options which are passed directly on to
    # the web services API in the query string.
    #
    # @option params [Boolean] :exclude_linked (false)
    #  Exclude items which are linked directly from this item.
    # @option params [Integer] :max_results (20)
    #  Only returns up to :max_results items.
    # @option params [Integer] :link_type_weight (1)
    #  Here link_type should be replace with one of the actual link types in
    #  use in your database, i.e. :purchase_weight and specifies how strongly
    #  links of that type should be weighted related to other link types.  For
    #  Instance if you wanted 20% ratings and 80% purchases you would specify:
    #  :purchases_weight => 8, :ratings_weight => 2
    #
    # This will not reflect any unsaved changes to items.
    #
    # @see Item#related

    def recommended(tags=Set.new, params={})
      normalize_params!(params)
      params['tags'] = tags.to_a.join(',')
      params.key?('excludeLinked') || params['excludeLinked'] = 'true'
      if with_properties?(params)
        property_hash_from_document(read_document('recommended', params), 'recommended')
      else
        list_from_document(read_document('recommended', params), 'recommended')
      end
    end

    # @return [String] The ID of the item.

    def to_s
      @id
    end

    # @return [String] An XML representation of the item as a string not including the
    # usual document regalia, e.g. starting with <item> (used for exporting the
    # item to a file)

    def to_xml
      insert_item(REXML::Document.new).to_s
    end

    private

    # Reads the tags / links / properties from the server if they are not
    # already cached.

    def read
      unless @cached
        document = read_document

        document.elements.each('//link') do |link_element|
          type = link_element.attribute('type')
          type = type ? type.to_s : ''
          weight = link_element.attribute('weight').to_s.to_i
          target = link_element.text
          @links[type][target] = weight unless @links[type][target]
        end

        @tags.merge(list_from_document(document, 'tag'))
        @preselected.concat(list_from_document(document, 'preselected'))
        @blacklisted.merge(list_from_document(document, 'blacklisted'))

        document.elements.each('//property') do |element|
          name = element.attribute('name').value
          @properties[name] = element.text unless @properties.has_key?(name)
        end

        @links_to_remove.each do |type, links|
          links.each { |link, weight| @links[type].delete(link) }
        end

        @tags_to_remove.each { |tag| @tags.delete(tag) }
        @preselected_to_remove.each { |p| @preselected.delete(p) }
        @blacklisted_to_remove.each { |b| @blacklisted.delete(b) }
        @properties_to_remove.each { |property| @properties.delete(property) }

        @links_to_remove.clear
        @tags_to_remove.clear
        @preselected_to_remove.clear
        @blacklisted_to_remove.clear
        @properties_to_remove.clear

        @cached = true
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

      @links_to_remove.each do |type, links|
        links.each do |link|
          element = item.add_element('link')
          element.add_attribute(type) unless type.empty?
          element.add_text(link.to_s)
        end
      end

      @tags_to_remove.each { |tag| item.add_element('tag').add_text(tag.to_s) }
      @preselected_to_remove.each { |p| item.add_element('preselected').add_text(p.to_s) }
      @blacklisted_to_remove.each { |b| item.add_element('blacklisted').add_text(b.to_s) }
      @properties_to_remove.each do |property|
        item.add_element('property').add_attribute('name', property.to_s)
      end
      item
    end

    def insert_item(document)
      item = setup_document(document)
      @links.each do |type, links|
        links.each do |link, weight|
          element = item.add_element('link')
          element.add_attribute('type', type) unless type.empty?
          element.add_attribute('weight', weight.to_s) unless weight == 0
          element.add_text(link.to_s)
        end
      end
      @tags.each { |tag| item.add_element('tag').add_text(tag.to_s) }
      @preselected.each { |p| item.add_element('preselected').add_text(p.to_s) }
      @blacklisted.each { |b| item.add_element('blacklisted').add_text(b.to_s) }
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
