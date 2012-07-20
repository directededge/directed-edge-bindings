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
    def initialize(database, id)
      @database = database
      @id = id.to_s
      @data = {
        :links => ContainerProxy.new(Array) { load },
        :tags => ContainerProxy.new(Array) { load },
        :properties => ContainerProxy.new(Hash) { load },
        :preselected => ContainerProxy.new(Array) { load },
        :blacklisted => ContainerProxy.new(Array) { load }
      }
    end

    def load
      data = XML.parse(resource.get)
      @data.keys.each { |key| @data[key].set(data[key]) }
      self
    end

    def save
      resource.put(to_xml(:cached_data)) if cached?
      resource[:update_method => :add].post(to_xml(:add_queue)) if queued?(:add)
      resource[:update_method => :subtract].post(to_xml(:remove_queue)) if queued?(:remove)
      @data.values.each(&:clear)
    end

    private

    def cached?
      @data.values.first.cached?
    end

    def queued?(add_or_remove)
      @data.values.reduce(false) { |c, v| c || !v.send("#{add_or_remove}_queue").empty? }
    end

    def resource
      @database.resource[@id]
    end

    def to_xml(data_method, with_header = true)
      values = Hash[@data.map { |k, v| [ k, v.send(data_method) ] }].merge(:id => @id)
      XML.generate(values, with_header)
    end

    def method_missing(name, *args, &block)
      @data.include?(name) ? @data[name] : super(name, *args, &block)
    end
  end
end
