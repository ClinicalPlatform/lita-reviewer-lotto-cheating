# frozen_string_literal: true

require 'reviewer_lotto_cheating/common/translatable'
require 'reviewer_lotto_cheating/responder'

module Lita::Handlers::ReviewerLottoCheating
  class BaseResponder
    include Translatable

    class << self
      def inherited(child)
        Responder.list << child
      end
    end
  end
end
