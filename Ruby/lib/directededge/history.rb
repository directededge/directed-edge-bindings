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

  # This specifies a history for which {HistoryEntry} instances can be created.
  # A classical example would be a history between a customer and a product.

  class History

    # @private

    class Proxy
      def initialize(database)
        @database = database
      end

      def add(history)
        resource[:update_method => :add].post(self.class.to_xml([ history ]))
        reset
      end

      def remove(history)
        resource[:update_method => :subtract].post(self.class.to_xml([ history ]))
        reset
      end

      private

      def resource
        @database.resource[:histories]
      end

      def method_missing(name, *args, &block)
        load.clone.freeze.send(name, *args, &block)
      end

      def reset
        @data = nil
      end

      def self.to_xml(histories)
        doc = XML.document
        histories.each do |history|
          node = Oga::XML::Element.new(:name => 'history')
          node.set('from', history.from)
          node.set('to', history.to)
          root = doc.children.first
          root.children << node
        end
        doc.to_xml
      end

      def load
        @data ||= XML.parse_list('history', @database.resource[:histories].get).map do |history|
          History.new(history.properties)
        end
      end
    end

    attr_reader :from, :to

    # @param [Hash] options
    # @option options [String] :from The type of item that is acting on the other
    # @option options [String] :to The type of item being acted upon

    def initialize(options)
      @from = (options[:from] || options['from']).to_s
      @to = (options[:to] || options['to']).to_s
    end

    def ==(other)
      @from == other.from && @to == other.to
    end
  end
end
