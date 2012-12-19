# Copyright (C) 2012 Directed Edge, Inc.
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
        :preselected => ContainerProxy.new(Array) { load },
        :blacklisted => ContainerProxy.new(Array) { load },
        :history_entries => ContainerProxy.new(Array) { load }
      }
      @query_cache = {}
    end

    def load
      begin
        data = XML.parse(resource[@options].get)
        @exists = true
      rescue RestClient::ResourceNotFound
        @exists = false
      end
      @data.keys.each { |key| @data[key].set(@exists ? data[key] : @data[key].klass.new) }
      self
    end

    def save
      if cached?
        resource.put(to_xml(:cached_data))
      else
        resource[:update_method => :add].post(to_xml(:add_queue))
        resource[:update_method => :subtract].post(to_xml(:remove_queue)) if queued?(:remove)
      end
      reset
    end

    def destroy
      resource.delete
      self
    end

    def reset
      @exists = nil
      @data.values.each(&:clear)
      @query_cache.clear
      self
    end

    def related(options = {})
      query(:related, options)
    end

    def recommended(options = {})
      query(:recommended, options.merge(:exclude_linked => true))
    end

    def [](key)
      @data[:properties][key]
    end

    def []=(key, value)
      @data[:properties].add(key => value)
    end

    def exists?
      load if @exists.nil?
      @exists
    end

    def to_s
      @id
    end

    private

    class LinkProxy < ContainerProxy
      def add(value, options = {})
        super(objectify(value, options))
      end

      def remove(value, options = {})
        super(objectify(value, options))
      end

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
      if options[:method] == 'POST'
        @query_cache[type][options] ||= XML.parse_list(type, resource[type].post(options))
      else
        @query_cache[type][options] ||= XML.parse_list(type, resource[type][options].get)
      end
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
