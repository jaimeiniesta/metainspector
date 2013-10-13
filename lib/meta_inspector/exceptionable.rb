# -*- encoding: utf-8 -*-

module MetaInspector
  #
  # This module extracts two common methods for classes that use ExceptionLog
  #
  module Exceptionable
    extend Forwardable
    def_delegators :@exception_log, :exceptions, :ok?
  end
end
