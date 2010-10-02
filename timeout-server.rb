#!/usr/bin/ruby

require 'rubygems'
require 'sinatra'

get '/api/v1/dummy/dummy/' do
  sleep 10
  'timeout'
end

get '/finished' do
  exit!
end
