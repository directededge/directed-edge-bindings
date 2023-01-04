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

  # A link between two items.
  #
  # Links can be weighted or unweighted (weight of 0), and optionally typed.
  #
  # Weights should only be used when the weight is intrinsic to the data
  # itself, not as an attetmpt to skew the results returned by the recommender.
  #
  # For that *link types* are appropriate:  with a link type you can change
  # the relative weight of every link in that category by passing options to
  # {Item#related} and {Item#recommended}.

  class Link
    attr_accessor :target, :weight, :type

    # @param [Hash] options
    # @option options [Integer] :weight (0)
    # @option options [String, Symbol] :type

    def initialize(target, options = {})
      @target = target.to_s
      @weight = options[:weight].to_i || 0
      @type = options[:type].to_s || ''
    end

    def ==(other)
      if other.is_a?(Link)
        @target == other.target && @weight == other.weight && @type == other.type
      elsif other.is_a?(Item)
        @target == other.id
      elsif other.is_a?(String) || other.is_a?(Symbol)
        @target == other.to_s
      else
        false
      end
    end
  end
end
