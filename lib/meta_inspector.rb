# -*- encoding: utf-8 -*-

require File.expand_path(File.join(File.dirname(__FILE__), 'meta_inspector/scraper'))

module MetaInspector
  extend self

  # Sugar method to be able to create a scraper in a shorter way
  def new(url, timeout = 20, html_content_only = false)
    Scraper.new(url, timeout, html_content_only)
  end
end
