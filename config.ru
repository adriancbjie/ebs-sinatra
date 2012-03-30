require 'rubygems'
require 'bundler'
require 'sinatra'
require 'thin'
require "sinatra/reloader"

Bundler.require
require './app'

Rack::Handler::Thin.run App