require 'nesty'

module MetaInspector
  class RequestError < StandardError
    include Nesty::NestedError
  end

  class ParserError < StandardError
    include Nesty::NestedError
  end
end
