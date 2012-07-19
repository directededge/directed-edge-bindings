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
      doc.find('//item').map do |item|
        {
          :id => item['id'],
          :links => item.find('//link').map { |l| Link.new(item['id'], l.first.to_s, l) },
          :tags => Reader.list(item, '//tag'),
          :preselcted => Reader.list(item, '//preselected'),
          :blacklisted => Reader.list(item, '//blacklisted'),
          :properties => Hash[item.find('//property').map { |p| [ p['name'], p.first.to_s ] }]
        }
      end
    end

    def self.generate(items)
      items = [ items ] unless items.is_a?(Array)

      doc = LibXML::XML::Document.new
      doc.root = LibXML::XML::Node.new('directededge')
      doc.root['version'] = '0.1'

      items.each do |item|
        doc.root << item_node = LibXML::XML::Node.new('item')

        item_node['id'] = item[:id]

        Writer.object(item_node, 'link', item[:links]) do |node, link|
          node << link.target.to_s
          node['weight'] = link.weight.to_s if link.weight > 0
          node['type'] = link.type.to_s unless link.type.to_s.empty?
        end

        Writer.list(item_node, 'tag', item[:tags])
        Writer.list(item_node, 'preselected', item[:preselected])
        Writer.list(item_node, 'blacklisted', item[:blacklisted])
        Writer.hash(item_node, 'property', 'name', item[:properties])
      end
      doc.to_s
    end

    private

    class Reader
      def self.list(node, search)
        node.find(search).map { |v| v.first.to_s }
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
