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

require 'set'

module DirectedEdge

  # A class that handles syncronization across the web services for data related
  # to {Item} instances.  It lets new tags, properties, links, etc. be set while
  # using a minimal number of calls across the web (using lazy evaluation) to
  # push or pull that info to the web services.

  class ContainerProxy
    # @private

    attr_reader :klass, :cached_data, :add_queue, :remove_queue

    # @private

    SUPPORTED_TYPES = [ Array, Hash, Set ]

    # @private

    def initialize(klass, &loader)
      @klass = klass
      @loader = loader
      clear
    end

    def add(*values)
      values.flatten!
      if cached?
        if array?
          @cached_data.push(*values)
        elsif set?
          @cached_data.merge(values)
        elsif hash?
          raise ArgumentError unless values.flatten.size == 1
          @cached_data.merge!(values.first)
        end
      else
        queue(@add_queue, @remove_queue, values)
      end
      values
    end

    def remove(value)
      if cached?
        if array? || set?
          @cached_data.delete(value)
        elsif hash?
          @cached_data.delete(value.is_a?(Hash) ? value.keys.first : value)
        end
      else
        queue(@remove_queue, @add_queue, value)
      end
      value
    end

    def set(values)
      @cached = true
      @cached_data = values

      @add_queue.each { |v| add(v) }
      @remove_queue.each { |v| remove(v) }

      @add_queue.clear
      @remove_queue.clear

      values
    end

    def clear
      @cached = false
      @cached_data = @klass.new
      @add_queue = @klass.new
      @remove_queue = @klass.new
    end

    def cached?
      @cached
    end

    def data
      @loader.call unless cached?
      @cached_data
    end

    def <=>(other)
      data <=> other.respond_to?(:data) ? other.data : other
    end

    def ==(other)
      data == other.respond_to?(:data) ? other.data : other
    end

    private

    def queue(add, subtract, *values)
      values.flatten!
      if array?
        add.push(*values.flatten)
        subtract.reject! { |v| values.include?(v) }
      elsif set?
        add.merge(values.flatten)
        subtract.reject! { |v| values.include?(v) }
      elsif hash?
        raise ArgumentError unless values.size == 1
        value = values.first
        value = { value => nil } unless value.is_a?(Hash)
        add.merge!(value)
        subtract.delete(value)
      end
    end

    def method_missing(name, *args, &block)
      SUPPORTED_TYPES.each do |type|
        return @cached_data.is_a?(type) if name.to_s == "#{type.name.downcase}?"
      end
      data.clone.freeze.send(name, *args, &block)
    end
  end
end
