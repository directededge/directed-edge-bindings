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

require 'rubygems'
require 'libxml'

module DirectedEdge
  class XML
    def self.parse(text)
      doc = LibXML::XML::Parser.string(text).parse
      node = doc.find('//item').first
      {
        :links => node.find('//link').map { |l| Link.new(l.first.to_s, l) },
        :tags => Reader.list(node, '//tag'),
        :preselected => Reader.list(node, '//preselected'),
        :blacklisted => Reader.list(node, '//blacklisted'),
        :properties => Hash[node.find('//property').map { |p| [ p['name'], p.first.to_s ] }]
      }
    end

    def self.parse_list(element, text)
      doc = LibXML::XML::Parser.string(text).parse
      Reader.list(doc, "//#{element}")
    end

    def self.generate(item, with_root = true)
      item_node = LibXML::XML::Node.new('item')

      if with_root
        doc = LibXML::XML::Document.new
        doc.root = LibXML::XML::Node.new('directededge')
        doc.root['version'] = '0.1'
        doc.root << item_node
      end

      item_node['id'] = item[:id]

      Writer.object(item_node, 'link', item[:links]) do |node, link|
        node << link.target
        node['weight'] = link.weight.to_s
        node['type'] = link.type.to_s unless link.type.to_s.empty?
      end

      Writer.list(item_node, 'tag', item[:tags])
      Writer.list(item_node, 'preselected', item[:preselected])
      Writer.list(item_node, 'blacklisted', item[:blacklisted])
      Writer.hash(item_node, 'property', 'name', item[:properties])

      with_root ? doc.to_s : item_node.to_s
    end

    private

    class Reader
      module Properties
        attr_accessor :properties
      end

      module Lookup
        def [](*args)
          return index_without_lookup(*args) if args.first.is_a?(Integer)
          each { |member| return member if member == args.first } ; nil
        end

        def self.extended(base)
          base.class.send :alias_method, :index_without_lookup, :[]
        end
      end

      def self.list(node, element)
        node.find(element).map do |node|
          value = node.first.to_s
          value.extend(Properties)
          value.properties = node.attributes.to_h
          value
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
          node << value.to_s
        end if values
      end
    end
  end
end
