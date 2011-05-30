# -*- encoding: utf-8 -*-

$: << File.join(File.dirname(__FILE__), "/../lib")
require 'meta_inspector'
require 'fakeweb'

FakeWeb.allow_net_connect = false

def fixture_file(filename)
  return '' if filename == ''
  file_path = File.expand_path(File.dirname(__FILE__) + '/fixtures/' + filename)
  File.read(file_path)
end