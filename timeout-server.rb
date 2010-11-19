#!/usr/bin/ruby

require 'rubygems'
require 'sinatra'

get '/api/*' do
  sleep 10
  'timeout'
end

get '/finished' do
  exit!
end
