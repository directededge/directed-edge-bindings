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

  # A job to update the Directed Edge web services in batch

  class UpdateJob
    HEADER = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<directededge version=\"0.1\">"
    FOOTER = "</directededge>\n"

    attr_reader :database

    # @param [Database] database
    # @param [:replace, :update] mode

    def initialize(database, mode)
      raise ArgumentError unless [ :replace, :update ].include?(mode)
      @database = database
      @mode = mode
      @add_file = temp(:add)
      @remove_file = temp(:remove) if mode == :update
    end

    # Creates a temporary item in a block to be added to the update job.
    # Typical usage would be:
    #
    #  UpdateJob.run('db', 'pass') do |job|
    #    job.item('foo') do |item|
    #      item.tags.add('bar')
    #    end
    #  end

    def item(id, &block)
      item = Item.new(self, id)
      block.call(item) if block
      validate_updates(item)
      @add_file.puts(item.to_xml(:add))
      @remove_file.puts(item.to_xml(:remove)) if @mode == :update
      item
    end

    # Removes item from the database.  This is only supported in :update mode.

    def destroy(item)
      raise StandardError unless @mode == :update
      @remove_file.puts(XML.generate({ :id => item.id }, false))
    end

    # Executes the update job

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

      unless ENV['DIRECTEDEDGE_DEBUG']
        @add_file.unlink
        @remove_file.unlink
      end
    end

    # Allows a job to be run from a block without having to create an instance.
    # The user name and password should be passed as arguments.

    def self.run(*args, &block)
      job =
        if args.length == 2
          raise ArgumentError unless args.first.is_a?(Database)
          self.new(args.first, args.last)
        elsif args.length == 3
          self.new(DirectedEdge::Database.new(args[0], args[1]), args[2])
        else
          raise ArgumentError
        end
      block.call(job)
      job.run
    end

    private

    # @private

    class Item < DirectedEdge::Item
      attr_reader :data

      def initialize(update_job, id)
        super(update_job.database, id)
        @update_job = update_job
      end

      def to_xml(add_or_remove)
        unless @destroy && !queued?(:add)
          method = add_or_remove == :add ? :add_queue : :remove_queue
          (method == :remove_queue && !queued?(:remove)) ? '' : super(method, false)
        end
      end

      def destroy
        @destroy = true
        @update_job.destroy(self)
      end

      private

      def load
        raise StandardError, 'You can\'t call load on Updater::Item'
      end

      def save
        raise StandardError, 'You can\'t call save on Updater::Item'
      end
    end

    def validate_updates(item)
      if @mode == :replace
        item.data.values.each do |v|
          if !v.remove_queue.empty?
            message = 'You can\'t remove values while the updater is in :replace mode'
            raise StandardError, message
          end
        end
      end
    end

    def temp(action)
      if ENV['DIRECTEDEDGE_DEBUG']
        file = File.open("/tmp/#{@database.name}-#{action}-#{Time.now.to_i}.xml", 'w+')
      else
        file = Tempfile.new("#{@database.name}-#{action}")
      end

      file.puts(HEADER)
      file
    end
  end
end
