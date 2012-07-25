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
require 'rest-client'

module DirectedEdge
  class Resource < RestClient::Resource
    def [](*args)
      return super(*(args.map { |v| CGI.escape(v.to_s) })) if args.empty? || !args[0].is_a?(Hash)
      params = args.first.map do |key, value|
        key = CGI.escape(key.to_s.gsub(/_\w/) { |s| s[1, 1].upcase })
        value = value.join(',') if value.is_a?(Array)
        value = CGI.escape(value.to_s)
        "#{key}=#{value}"
      end
      super('?' + params.join('&'))
    end

    def get(additional_headers = {}, &block)
      additional_headers[:content_type] ||= 'text/xml'
      super(additional_headers, &block)
    end

    def put(payload, additional_headers = {}, &block)
      additional_headers[:content_type] ||= 'text/xml'
      super(payload, additional_headers, &block)
    end

    def post(payload, additional_headers = {}, &block)
      additional_headers[:content_type] ||= 'text/xml'
      super(payload, additional_headers, &block)
    end
  end
end
