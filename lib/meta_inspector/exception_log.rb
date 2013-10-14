# -*- encoding: utf-8 -*-

module MetaInspector

  # Stores the exceptions passed to it, warning about them if required
  class ExceptionLog
    attr_reader :exceptions, :warn_level

    def initialize(options = {})
      @exceptions = []
      @warn_level = options[:warn_level]
    end

    def <<(exception)
      warn exception if warn_level == :warn
      @exceptions << exception
    end

    def ok?
      exceptions.empty?
    end
  end
end
