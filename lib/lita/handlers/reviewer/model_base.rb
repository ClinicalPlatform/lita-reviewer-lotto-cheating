require_relative 'registory'

module Lita::Handlers::Reviewer
  class ModelBase
    def self.inherited(child)
      Registory.models << child
    end
  end
end
