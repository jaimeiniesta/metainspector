require 'forwardable'
require_relative 'meta_inspector/version'
require_relative 'meta_inspector/errors'
require_relative 'meta_inspector/url'
require_relative 'meta_inspector/request'
require_relative 'meta_inspector/image_downloader'
require_relative 'meta_inspector/parser'
require_relative 'meta_inspector/parsers/base'
require_relative 'meta_inspector/parsers/images'
require_relative 'meta_inspector/parsers/iframes'
require_relative 'meta_inspector/parsers/links'
require_relative 'meta_inspector/parsers/head_links'
require_relative 'meta_inspector/parsers/meta_tags'
require_relative 'meta_inspector/parsers/texts'
require_relative 'meta_inspector/document'

module MetaInspector
  extend self

  # Sugar method to be able to scrape a document in a shorter way
  def new(url, options = {})
    Document.new(url, options)
  end
end
