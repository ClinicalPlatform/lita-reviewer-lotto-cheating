# frozen_string_literal: true

require 'reviewer_lotto_cheating/model'

module Lita::Handlers::ReviewerLottoCheating
  class BaseModel
    def self.inherited(child)
      Model.list << child
    end
  end
end
