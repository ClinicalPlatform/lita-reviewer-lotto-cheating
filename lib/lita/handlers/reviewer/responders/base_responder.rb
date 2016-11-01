require_relative '../common/traslatable'
require_relative '../responder'

module Lita::Handlers::Reviewer
  class BaseResponder
    include Translatable

    class << self
      def inherited(child)
        Responder.list << child
      end
    end
  end
end
