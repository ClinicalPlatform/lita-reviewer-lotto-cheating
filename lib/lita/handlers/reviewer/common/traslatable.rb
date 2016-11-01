module Lita::Handlers::Reviewer
  module Translatable
    def translate(key, hash = {})
      I18n.translate("lita.handlers.reviewer.#{key}", hash)
    end

    alias t translate
  end
end
