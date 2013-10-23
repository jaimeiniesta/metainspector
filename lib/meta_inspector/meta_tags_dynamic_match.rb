module MetaInspector

  # Encapsulates matching for method_missing and respond_to? for meta tags methods
  class MetaTagsDynamicMatch
    attr_reader :meta_tag

    def initialize(method_name)
      if method_name.to_s =~ /^meta_(.+)/
        @meta_tag = $1
      end
    end

    def match?
      @meta_tag
    end

  end
end