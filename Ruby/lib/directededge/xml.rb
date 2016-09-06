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

  ### MAYBE REMOVE ITEM REFERENCES HERE!?

  # @private

  class XML

    INVALID_XML_CHARS = /[^\x09\x0A\x0D\x20-\u{D7FF}\u{E000}-\u{FFFD}\u{10000}-\u{10FFFF}]/

    def self.parse_item(database, text)
      self.parse_items(database, text).first
    end

    def self.parse_items(database, text)
      doc = LibXML::XML::Parser.string(text).parse
      doc.find('//item').map do |node|
        {
          :id => node[:id],
          :links => node.find('.//link').map { |l| Link.new(l.first.to_s, l) },
          :tags => Reader.list(node, './/tag'),
          :preselected => Reader.list(node, './/preselected') { |id| Item.new(database, id) },
          :blacklisted => Reader.list(node, './/blacklisted') { |id| Item.new(database, id) },
          :properties => Hash[node.find('.//property').map { |p| [ p['name'], p.first.to_s ] }],
          :history_entries => node.find('.//history').map do |h|
            history = History.new(:from => h[:from], :to => h[:to])
            HistoryEntry.new(history, h.first.to_s, h.attributes.to_h)
          end
        }
      end
    end

    def self.parse_list(element, text, &block)
      doc = LibXML::XML::Parser.string(text).parse
      Reader.list(doc, "//#{element}", &block)
    end

    def self.generate(item, with_root = true)
      item_node = LibXML::XML::Node.new('item')

      if with_root
        doc = document
        doc.root << item_node
      end

      item_node['id'] = item[:id]

      Writer.object(item_node, 'link', item[:links]) do |node, link|
        node << link.target
        node['weight'] = link.weight.to_s if link.weight != 0
        node['type'] = link.type.to_s unless link.type.to_s.empty?
      end

      Writer.list(item_node, 'tag', item[:tags])
      Writer.list(item_node, 'preselected', item[:preselected])
      Writer.list(item_node, 'blacklisted', item[:blacklisted])
      Writer.hash(item_node, 'property', 'name', item[:properties])

      Writer.object(item_node, 'history', item[:history_entries]) do |node, entry|
        node << entry.target
        node['from'] = entry.history.from.to_s
        node['to'] = entry.history.to.to_s
        node['timestamp'] = entry.timestamp.to_s if entry.timestamp
      end

      with_root ? doc.to_s : item_node.to_s
    end

    def self.document
      doc = LibXML::XML::Document.new
      doc.root = LibXML::XML::Node.new('directededge')
      doc.root['version'] = '0.1'
      doc
    end

    private

    class Reader
      module Properties
        attr_accessor :properties
      end

      module Lookup
        def [](*args)
          each { |m| return m if m == args.first } unless args.first.is_a?(Integer)
          index_without_lookup(*args)
        end

        def self.extended(base)
          base.class.send(:alias_method, :index_without_lookup, :[])
        end
      end

      def self.list(node, element, &block)
        value = node.find(element).map do |n|
          value = n.first.to_s
          value.extend(Properties)
          value.properties = n.attributes.to_h
          block ? block.call(value) : value
        end.extend(Lookup)
      end
    end

    class Writer
      def self.object(parent, name, values, &block)
        values.each do |object|
          parent << node = LibXML::XML::Node.new(name)
          block.call(node, object)
        end if values
      end

      def self.list(parent, name, values)
        values.each { |v| parent << (LibXML::XML::Node.new(name.to_s) << v.to_s) } if values
      end

      def self.hash(parent, element_name, attribute_name, values)
        values.each do |key, value|
          parent << node = LibXML::XML::Node.new(element_name)
          node[attribute_name] = key.to_s
          node << value.to_s.gsub(INVALID_XML_CHARS, '')
        end if values
      end
    end
  end
end
