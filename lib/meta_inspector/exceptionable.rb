module MetaInspector
  #
  # This module extracts two common methods for classes that use ExceptionLog
  #
  module Exceptionable
    extend Forwardable
    delegate [:exceptions, :ok?] => :@exception_log
  end
end
