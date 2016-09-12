# Copyright (C) 2012-2016 Directed Edge, Inc.
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
  # @example
  #
  #   database = DirectedEdge::Database.new('mydatabase', 'mypassword')

  class Database
    include ItemQuery

    attr_reader :resource, :name

    # @param [String] name Directed Edge user name
    # @param [String] password Directed Edge password
    # @param [Hash] options
    # @option options [String] :host ('webservices.directededge.com')
    # @option options [Integer] :port (80)
    # @option options [Integer] :timeout (10) Timeout in seconds

    def initialize(name, password, options = {})
      @name = name
      protocol = options[:protocol] || 'http'
      host = options[:host] || ENV['DIRECTEDEDGE_HOST'] || 'webservices.directededge.com'
      port = options[:port] || 80
      url = "#{protocol}://#{CGI.escape(name)}:#{CGI.escape(password)}@#{host}:#{port}" +
        "/api/v1/#{name}"
      options[:timeout] ||= 10
      @resource = DirectedEdge::Resource.new(url, options)
    end

    # WARNING: Deletes all data in the current database.  Use with extreme
    # caution.

    def clear!
      @resource.delete
    end

    # Returns a list of items
    # @param ids The list of item IDs to return

    def items(ids, options = {})
      XML.parse_items(@database, @resource[options.merge(:items => ids)].get).map do |data|
        Item.new(self, data[:id], data)
      end
    end

    # Exports the contents of the database on the Directed Edge server to a file
    #
    # @param [String] filename

    def export(filename)
      uri = URI(@resource.url)
      Net::HTTP.start(uri.host, uri.port) do |http|
        request = Net::HTTP::Get.new(uri.request_uri)
        request.basic_auth(uri.user, uri.password)
        http.request(request) do |response|
          File.open(filename, 'w') { |io| response.read_body { |chunk| io.write(chunk) } }
        end
      end
    end

    # Imports the contents of the specified file to the Directed Edge server,
    # overwriting any previously existing content.
    #
    # @param [String] filename

    def import(filename)
      file = File.open(filename, 'r')
      @resource.put(file)
    end

    # Finds a set of items that are related to the specified set of items.  This
    # is commonly used for shopping cart recommendations.
    #
    # @param [Array<Item>, Array<String>] Set of items (e.g. basket contents) to
    #  for which to find related items
    # @return [Array<Item>] A list of related items, sorted by relevance
    #
    # @see Item#related

    def related(items, options = {})
      options[:items] = items
      options[:union] = true
      item_query(self, :related, @resource[:related][options])
    end

    # Databases have a defined set of histories that can be tracked that track
    # the interaction between one type of item and another.
    #
    # @return [Array<History>] The list of defined histories for this database
    #
    # @see History

    def histories
      @history_proxy ||= History::Proxy.new(self)
    end

    # Sets the list of histories
    #
    # @see History

    def histories=(list)
      resource[:histories].put(History::Proxy.to_xml(list))
      @history_proxy = nil
      list
    end
  end
end
