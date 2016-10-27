require_relative '../registory'

module Lita::Handlers::Reviewer::Responders
  class Base
    class << self
      def inherited(child)
        Lita::Handlers::Reviewer::Registory.responders << child
      end
    end

    def translate(key, hash = {})
      I18n.translate("lita.handlers.reviewer.#{key}", hash)
    end

    alias t translate
  end
end

