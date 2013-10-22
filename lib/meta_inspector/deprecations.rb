# -*- encoding: utf-8 -*-

module MetaInspector
  class Scraper < Document
    def initialize
      warn "The Scraper class is now deprecated since version 1.17, use Document instead"
      super
    end

    def errors
      warn "The #errors method is deprecated since version 1.17, use #exceptions instead"
      exceptions
    end

    def document
      warn "The #document method is deprecated since version 1.17, use #to_s instead"
    end
  end
end
