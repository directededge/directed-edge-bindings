# Copyright (C) 2012-2013 Directed Edge, Inc.
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

module DirectedEdge
  class ContainerProxy ; end

  # Represents an item in a Directed Edge database.  Items can be products, pages
  # or users, for instance.  Usually items groups are differentiated from one
  # another by a set of tags that are provided.
  #
  # For instance, a user in the Directed Edge database could be modeled as:
  #
  #   user = DirectedEdge::Item.new(database, 'user_1')
  #   user.tags.add('user')
  #   user.save
  #
  # Similarly a product could be:
  #
  #   product = DirectedEdge::Item.new(database, 'product_1')
  #   product.tags.add('product')
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
  #   user.links.add(product)
  #   user.save
  #
  # == Pseudo-methods to return item info
  #
  # There are four special pseudo-methods that point to attributes / lists
  # related to the item:
  #
  # - links (Array<String>)
  # - tags (Array<String>)
  # - properties (Hash)
  # - preselected (Array<String>)
  # - blacklisted (Array<String>)
  # - history_entries (Array<HistoryEntry>)
  #
  # Each of those methods returns a {ContainerProxy}.  ContainerProxies have a
  # very simple API.  They simply support the operations:
  #
  # - {ContainerProxy#add}
  # - {ContainerProxy#remove}
  # - {ContainerProxy#set}
  # - {ContainerProxy#cached?}
  #
  # Those let you do things like add and remove individual tags (or preselected
  # items, or whatever) or set the entire list.

  class Item
    attr_reader :id

    def initialize(database, id, options = {})
      @database = database
      @id = id.to_s
      @options = options
      @data = {
        :links => LinkProxy.new(Array) { load },
        :tags => ContainerProxy.new(Array) { load },
        :properties => ContainerProxy.new(Hash) { load },
        :preselected => ItemProxy.new(database) { load },
        :blacklisted => ItemProxy.new(database) { load },
        :history_entries => ContainerProxy.new(Array) { load }
      }

      @data.keys.each { |key| @data[key].set(options[key]) if options[key] }

      @query_cache = {}
    end

    # Loads the item's data from the Directed Edge server.
    #
    # This is called automatically from accessor methods.
    #
    # @return [Item]

    def load
      begin
        data = XML.parse_item(@database, resource[@options].get)
        @exists = true
      rescue RestClient::ResourceNotFound
        @exists = false
      end
      @data.keys.each { |key| @data[key].set(@exists ? data[key] : @data[key].klass.new) }
      self
    end

    # Writes all changes to links, tags and properties back to the database and
    # returns this item.
    #
    # @return [Item]

    def save
      if cached?
        resource.put(to_xml(:cached_data))
      else
        resource[:update_method => :add].post(to_xml(:add_queue))
        resource[:update_method => :subtract].post(to_xml(:remove_queue)) if queued?(:remove)
      end
      reset
      self
    end

    # Removes an item from the database, including deleting all links to and
    # from this item.
    #
    # @return [Item]

    def destroy
      resource.delete
      self
    end

    # Clears the cached information about this item that was pulled from the
    # Directed Edge servers in Item#load.
    #
    # @return [Item]

    def reset
      @exists = nil
      @data.values.each(&:clear)
      @query_cache.clear
      self
    end

    # {#related} and {#recommended} are the two main methods for querying
    # for recommendations with the Directed Edge API.  Related is for *similar*
    # items, e.g. "products like this product", whereas recommended is for
    # personalized recommendations, i.e. "We think you'd like..."
    #
    # @return [Array] List of item IDs related to this one with the most closely
    # related items first.
    # 
    # @param [Hash] options A set of options which are passed directly on to the
    #  web services API in the query string.
    # @option options [String, [Array<String>]] :tags
    #  Only include items which possess the specified tags
    # @option options [String, [Array<String>]] :excluded_tags
    #  Do not include items which contain the specified tags
    # @option options [String] :tag_operation ('OR')
    #  Can specify AND or OR as the means for matching when using multiple
    #  tags with the options above.
    # @option options [Array] :excluded
    #  Don't included any of the item IDs listed in the result set
    # @option options [Boolean] :exclude_linked (false)
    #  Exclude items which are linked directly from this item.
    # @option options [Integer] :max_results (20)
    #  Only returns up to :max_results items.
    # @option options [Integer] :link_type_weight (1)
    #  Here `link_type` should be replace with one of the actual link types in
    #  use in your database, i.e. :purchase_weight and specifies how strongly
    #  links of that type should be weighted related to other link types.  For
    #  Instance if you wanted 20% ratings and 80% purchases you would specify:
    #  :purchases_weight => 8, :ratings_weight => 2
    #
    # This will not reflect any unsaved changes to items.
    #
    # @see Item#recommended

    def related(options = {})
      query(:related, options)
    end

    # {#recommended} and {#related} are the two main methods for querying for
    # recommendations with the Directed Edge API.  Related is for *similar*
    # items, e.g. "products like this product", whereas recommended is for
    # personalized recommendations, i.e. "We think you'd like..."
    #
    # @return [Array] List of item IDs related to this one with the most closely
    # related items first.
    # 
    # @param [Hash] options A set of options which are passed directly on to
    # the web services API in the query string.
    #
    # @option options [Array] :tags
    #  Only include items which possess the specified tags
    # @option options [Array] :excluded_tags
    #  Do not include items which contain the specified tags
    # @option options [String] :tag_operation ('OR')
    #  Can specify AND or OR as the means for matching when using multiple
    #  tags with the options above.
    # @option options [Array] :excluded
    #  Don't included any of the item IDs listed in the result set
    # @option options [Boolean] :exclude_linked (true)
    #  Exclude items which are linked directly from this item.
    # @option options [Integer] :max_results (20)
    #  Only returns up to :max_results items.
    # @option options [Integer] :link_type_weight (1)
    #  Here link_type should be replace with one of the actual link types in
    #  use in your database, i.e. :purchase_weight and specifies how strongly
    #  links of that type should be weighted related to other link types.  For
    #  Instance if you wanted 20% ratings and 80% purchases you would specify:
    #  :purchases_weight => 8, :ratings_weight => 2
    #
    # This will not reflect any unsaved changes to items.
    #
    # @see Item#related

    def recommended(options = {})
      query(:recommended, options.merge(:exclude_linked => true))
    end

    # Fetches a property of the item.
    #
    # @return [String] The property for this item.

    def [](key)
      @data[:properties][key]
    end

    # Assigns a property value to the given key.
    #
    # This will not be written back to the database until Item#save is called.
    #
    # @return [Item]

    def []=(key, value)
      @data[:properties].add(key => value)
    end

    # Returns true if the item already exists on the Directed Edge server.
    #
    # @return [Boolean]

    def exists?
      load if @exists.nil?
      @exists
    end

    # Returns the item ID.
    #
    # @return [String]

    def to_s
      @id
    end

    def ==(other)
      other.is_a?(Item) ? id == other.id : false
    end

    private

    # @private

    class ObjectProxy < ContainerProxy
      def add(value, options = {})
        super(objectify(value, options))
      end

      def remove(value, options = {})
        super(objectify(value, options))
      end
    end

    class LinkProxy < ObjectProxy
      def [](id, type = '')
        return super(id) if id.is_a?(Integer)
        each { |member| return member if member == id && member.type == type.to_s } ; nil
      end

      def objectify(value, options)
        if value.is_a?(String) || value.is_a?(Symbol)
          Link.new(value, options)
        elsif value.is_a?(Item)
          Link.new(value.id, options)
        else
          value
        end
      end
    end

    class ItemProxy < ObjectProxy
      def initialize(database, &loader)
        @database = database
        super(Array, &loader)
      end

      def [](id)
        return super(id) if id.is_a?(Integer)
        each { |member| return member if member == id } ; nil
      end

      def objectify(value, options)
        value.is_a?(String) ? Item.new(@database, value) : value
      end
    end

    module ItemLookup
      def [](*args)
        each { |m| return m if m.id == args.first } if args.first.is_a?(String)
        index_without_item_lookup(*args)
      end

      def self.extended(base)
        base.class.send(:alias_method, :index_without_item_lookup, :[])
      end
    end

    def cached?
      @data.values.first.cached?
    end

    def queued?(add_or_remove)
      @data.values.reduce(false) { |c, v| c || !v.send("#{add_or_remove}_queue").empty? }
    end

    def resource
      @database.resource['items'][@id]
    end

    def query(type, options)
      @query_cache[type] ||= {}
      @query_cache[type][options] ||= XML.parse_list(type, resource[type][options].get) do |i|
        Item.new(@database, i, :properties => i.properties)
      end.extend(ItemLookup)
    end

    def to_xml(data_method, with_header = true)
      values = Hash[@data.map { |k, v| [ k, v.send(data_method) ] }].merge(:id => @id)
      XML.generate(values, with_header)
    end

    def method_missing(method, *args, &block)
      @data.include?(method.to_sym) ? @data[method.to_sym] : super
    end
  end
end
