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
  class Database
    attr_reader :resource, :name

    def initialize(name, password, options = {})
      @name = name
      host = options[:host] || ENV['DIRECTEDEDGE_HOST'] || 'webservices.directededge.com'
      protocol = options[:protocol] || 'http'
      url = "#{protocol}://#{name}:#{password}@#{host}/api/v1/#{name}"
      options[:timeout] ||= 10
      @resource = DirectedEdge::Resource.new(url, options)
    end

    def export_to_file(filename)
      uri = URI(@resource.url)
      Net::HTTP.start(uri.host, uri.port) do |http|
        request = Net::HTTP::Get.new(uri.request_uri)
        request.basic_auth(uri.user, uri.password)
        http.request(request) do |response|
          File.open(filename, 'w') { |io| response.read_body { |chunk| io.write(chunk) } }
        end
      end
    end

    def import_from_file(filename)
      file = File.open(filename, 'r')
      @resource.put(file)
    end
  end
end
