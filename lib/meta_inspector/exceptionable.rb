# -*- encoding: utf-8 -*-

module MetaInspector
  #
  # This module extracts two common methods for classes that use ExceptionLog
  #
  module Exceptionable
    # Returns the list of stored exceptions
    def exceptions
      @exception_log.exceptions
    end

    # Returns true if there are no exceptions
    def ok?
      exceptions.empty?
    end
  end
end
