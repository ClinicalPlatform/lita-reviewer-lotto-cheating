require_relative '../registory'

module Lita
  module Handlers
    class Reviewer < Handler
      module Responsers
        class Base
          class << self
            def inherited(child)
              Registory.responsers << child
            end
          end

          def translate(key, hash = {})
            I18n.translate("lita.handlers.reviewer.#{key}", hash)
          end

          alias t translate
        end
      end
    end
  end
end

