# Allow open-uri to follow unsafe redirects (i.e. https to http).
# Relevant issue:
# http://redmine.ruby-lang.org/issues/3719
# Source here:
# https://github.com/ruby/ruby/blob/trunk/lib/open-uri.rb
# Original gist URL:
# https://gist.github.com/1271420
module OpenURI
  class <<self
    alias_method :open_uri_original, :open_uri
    alias_method :redirectable_cautious?, :redirectable?

    def redirectable_unsafe? uri1, uri2
      valid = /\A(?:https?)\z/i
      valid =~ uri1.scheme.downcase && valid =~ uri2.scheme
    end

    def redirectable_safe? uri1, uri2
      uri1.scheme.downcase == uri2.scheme.downcase || (uri1.scheme.downcase == "http" && uri2.scheme.downcase == "https")
    end
  end

  # The original open_uri takes *args but then doesn't do anything with them.
  # Assume we can only handle a hash.
  def self.open_uri name, options = {}
    redirectable_unsafe = options.delete :allow_unsafe_redirections
    redirectable_safe = options.delete :allow_safe_redirections

    if redirectable_unsafe
      class <<self
        remove_method :redirectable?
        alias_method :redirectable?, :redirectable_unsafe?
      end
    elsif redirectable_safe
      class <<self
        remove_method :redirectable?
        alias_method :redirectable?, :redirectable_safe?
      end
    else
      class <<self
        remove_method :redirectable?
        alias_method :redirectable?, :redirectable_cautious?
      end
    end
    
    self.open_uri_original name, options
  end
end