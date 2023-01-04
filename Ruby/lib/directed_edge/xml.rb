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

  ### MAYBE REMOVE ITEM REFERENCES HERE!?

  # @private

  class XML

    INVALID_XML_CHARS = /[^\x09\x0A\x0D\x20-\u{D7FF}\u{E000}-\u{FFFD}\u{10000}-\u{10FFFF}]/

    def self.parse_item(database, text)
      self.parse_items(database, text).first
    end

    def self.parse_items(database, text)
      doc = Oga.parse_xml(text)
      doc.xpath('//item').map do |element|
        links = element.xpath('.//link').map do |link|
          attributes = Hash[attributes_to_hash(link).map { |k, v| [ k.to_sym, v ] }]
          Link.new(link.inner_text, attributes)
        end
        {
          :id => element.get('id'),
          :links => links,
          :tags => Reader.list(element, './/tag'),
          :preselected => Reader.list(element, './/preselected') { |id| Item.new(database, id) },
          :blacklisted => Reader.list(element, './/blacklisted') { |id| Item.new(database, id) },
          :properties => Hash[element.xpath('.//property').map { |p|
                                [ p.get('name'), p.inner_text ] }],
          :history_entries => element.xpath('.//history').map do |h|
            history = History.new(:from => h.get('from'), :to => h.get('to'))
            HistoryEntry.new(history, h.inner_text, attributes_to_hash(h))
          end
        }
      end
    end

    def self.parse_list(element, text, &block)
      doc = Oga.parse_xml(text)
      Reader.list(doc, "//#{element}", &block)
    end

    def self.generate(item, with_root = true)
      item_element = Oga::XML::Element.new(:name => 'item')

      if with_root
        doc = document
        root = doc.children.last
        root.children << item_element
      end

      item_element.set('id', item[:id])

      Writer.object(item_element, 'link', item[:links]) do |element, link|
        element.inner_text = link.target
        element.set('weight', link.weight.to_s) if link.weight != 0
        element.set('type', link.type.to_s) unless link.type.to_s.empty?
      end

      Writer.list(item_element, 'tag', item[:tags])
      Writer.list(item_element, 'preselected', item[:preselected])
      Writer.list(item_element, 'blacklisted', item[:blacklisted])
      Writer.hash(item_element, 'property', 'name', item[:properties])

      Writer.object(item_element, 'history', item[:history_entries]) do |element, entry|
        element.inner_text = entry.target
        element.set('from', entry.history.from.to_s)
        element.set('to', entry.history.to.to_s)
        element.set('timestamp', entry.timestamp.to_s) if entry.timestamp
      end

      with_root ? doc.to_xml : item_element.to_xml
    end

    def self.document
      doc = Oga::XML::Document.new
      root = Oga::XML::Element.new(:name => 'directededge')
      doc.children << root
      doc
    end

    private

    def self.attributes_to_hash(element)
      Hash[element.attributes.map { |a| [ a.name, a.value ] }]
    end

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

      def self.list(element, element_name, &block)
        value = element.xpath(element_name).map do |e|
          value = e.inner_text
          value.extend(Properties)
          value.properties = XML.attributes_to_hash(e)
          block ? block.call(value) : value
        end.extend(Lookup)
      end
    end

    class Writer
      def self.object(parent, name, values, &block)
        values.each do |object|
          element = Oga::XML::Element.new(:name => name)
          parent.children << element
          block.call(element, object)
        end if values
      end

      def self.list(parent, name, values)
        if values
          values.each do |v|
            element = Oga::XML::Element.new(:name => name.to_s)
            element.inner_text = sanitize(v)
            parent.children << element
          end
        end
      end

      def self.hash(parent, element_name, attribute_name, values)
        values.each do |key, value|
          element = Oga::XML::Element.new(:name => element_name)
          parent.children << element
          element.set(attribute_name, key.to_s)
          element.inner_text = sanitize(value)
        end if values
      end

      private

      def self.sanitize(v)
        v.to_s.gsub(INVALID_XML_CHARS, '')
      end
    end
  end
end
