module MetaInspector
  class Scraper
    def errors
      warn "The #errors method is deprecated since version 1.16.2, use #exceptions instead"
      exceptions
    end
  end
end
