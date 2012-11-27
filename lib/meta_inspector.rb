# -*- encoding: utf-8 -*-

require File.expand_path(File.join(File.dirname(__FILE__), 'meta_inspector/scraper'))
require File.expand_path(File.join(File.dirname(__FILE__), 'meta_inspector/open_uri'))

module MetaInspector
  extend self

  # Sugar method to be able to create a scraper in a shorter way
  def new(url, options = {})
    Scraper.new(url, options)
  end
end
