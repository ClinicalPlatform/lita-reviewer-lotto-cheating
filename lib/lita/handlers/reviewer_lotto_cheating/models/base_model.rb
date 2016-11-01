# frozen_string_literal: true

require_relative '../model'

module Lita::Handlers::ReviewerLottoCheating
  class BaseModel
    def self.inherited(child)
      Model.list << child
    end
  end
end
