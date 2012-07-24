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

require 'tempfile'

module DirectedEdge
  class UpdateJob
    HEADER = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<directededge version=\"0.1\">"
    FOOTER = "</directededge>\n"

    def initialize(database, mode)
      raise ArgumentError.new unless [ :replace, :update ].include?(mode)
      @database = database
      @mode = mode
      @add_file = temp(:add)
      @remove_file = temp(:remove) if mode == :update
    end

    def item(id, &block)
      item = Item.new(@database, id)
      block.call(item)
      validate_updates(item)
      @add_file.puts(item.to_xml(:add))
      @remove_file.puts(item.to_xml(:remove)) if @mode == :update
      item
    end

    def run
      (@mode == :replace ? [ @add_file ] : [ @add_file, @remove_file ]).each do |file|
        file.puts(FOOTER)
        file.flush
        file.rewind
      end

      if @mode == :replace
        @database.resource.put(@add_file)
      elsif @mode == :update
        @database.resource[:update_method => :add].post(@add_file)
        @database.resource[:update_method => :subtract].post(@remove_file)
      end
    end

    private

    class Item < DirectedEdge::Item
      attr_reader :data

      def to_xml(add_or_remove)
        method = add_or_remove == :add ? :add_queue : :remove_queue
        queued?(add_or_remove) ? super(method, false) : ''
      end

      private

      def load
        raise StandardError.new('You can\'t call load on Updater::Item')        
      end

      def save
        raise StandardError.new('You can\'t call save on Updater::Item')
      end
    end

    def validate_updates(item)
      if @mode == :replace
        item.data.values.each do |v|
          if !v.remove_queue.empty?
            message = 'You can\'t remove values while the updater is in :replace mode'
            raise StandardError.new(message)
          end
        end
      end
    end

    def temp(action)
      file = Tempfile.new("#{@database.name}-#{action}")
      file.puts(HEADER)
      file
    end
  end
end
