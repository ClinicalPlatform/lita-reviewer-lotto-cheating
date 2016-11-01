module Lita::Handlers::ReviewerLottoCheating
  module Translatable
    def translate(key, hash = {})
      I18n.translate("lita.handlers.reviewer_lotto_cheating.#{key}", hash)
    end

    alias t translate
  end
end
