# -*- encoding: utf-8 -*-

module MetaInspector

  # Stores the exceptions passed to it, warning about them if required
  class ExceptionLog
    attr_reader :exceptions, :verbose

    def initialize(options = {})
      @exceptions = []
      @verbose    = options[:verbose] || false
    end

    def <<(exception)
      warn exception if verbose
      @exceptions << exception
    end

  end
end
