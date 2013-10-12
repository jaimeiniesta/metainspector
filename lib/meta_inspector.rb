# -*- encoding: utf-8 -*-

require File.expand_path(File.join(File.dirname(__FILE__), 'meta_inspector/exceptionable'))
require File.expand_path(File.join(File.dirname(__FILE__), 'meta_inspector/exception_log'))
require File.expand_path(File.join(File.dirname(__FILE__), 'meta_inspector/request'))
require File.expand_path(File.join(File.dirname(__FILE__), 'meta_inspector/scraper'))

module MetaInspector
  extend self

  # Sugar method to be able to create a scraper in a shorter way
  def new(url, options = {})
    Scraper.new(url, options)
  end
end
