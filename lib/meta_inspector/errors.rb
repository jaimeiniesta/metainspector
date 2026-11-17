require 'nesty'

module MetaInspector
  class Error < StandardError
    include Nesty::NestedError
  end

  class TimeoutError < Error; end

  class RequestError < Error; end

  class ParserError < Error; end

  class NonHtmlError < ParserError
    def self.for(content_type)
      new("The url provided contains #{content_type} content instead of text/html content")
    end
  end
end
