# -*- encoding: utf-8 -*-

module MetaInspector

  # Stores the exceptions passed to it, warning about them if required
  class ExceptionLog
    attr_reader :exceptions, :warn_level

    def initialize(options = {})
      options     = defaults.merge(options)
      @warn_level = options[:warn_level]
      @exceptions = []
    end

    def <<(exception)
      case warn_level
      when :raise
        raise exception
      when :warn
        warn exception
      when :store
        @exceptions << exception
      end
    end

    def ok?
      if warn_level == :store
        exceptions.empty?
      else
        warn "ExceptionLog#ok? should only be used when warn_level is :store"
      end
    end

    private

    def defaults
      { warn_level: :raise }
    end
  end
end
