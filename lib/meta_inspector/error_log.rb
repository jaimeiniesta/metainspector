# -*- encoding: utf-8 -*-

module MetaInspector

  # Stores the errors messages passed to it, warning about them if required
  class ErrorLog
    attr_reader :errors, :verbose

    def initialize(options = {})
      @errors   = []
      @verbose  = options[:verbose] || false
    end

    def <<(error)
      warn error if verbose
      @errors << error
    end

  end
end
