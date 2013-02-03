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
  class Database
    attr_reader :resource, :name

    def initialize(name, password, options = {})
      @name = name
      protocol = options[:protocol] || 'http'
      host = options[:host] || ENV['DIRECTEDEDGE_HOST'] || 'webservices.directededge.com'
      port = options[:port] || 80
      url = "#{protocol}://#{name}:#{password}@#{host}:#{port}/api/v1/#{name}"
      options[:timeout] ||= 10
      @resource = DirectedEdge::Resource.new(url, options)
    end

    def export(filename)
      uri = URI(@resource.url)
      Net::HTTP.start(uri.host, uri.port) do |http|
        request = Net::HTTP::Get.new(uri.request_uri)
        request.basic_auth(uri.user, uri.password)
        http.request(request) do |response|
          File.open(filename, 'w') { |io| response.read_body { |chunk| io.write(chunk) } }
        end
      end
    end

    def import(filename)
      file = File.open(filename, 'r')
      @resource.put(file)
    end

    def related(items, options = {})
      options[:items] = items
      options[:union] = true
      XML.parse_list(:related, @resource[:related][options].get)
    end

    def histories
      @history_proxy ||= History::Proxy.new(self)
    end

    def histories=(list)
      resource[:histories].put(History::Proxy.to_xml(list))
      @history_proxy = nil
      list
    end
  end
end
