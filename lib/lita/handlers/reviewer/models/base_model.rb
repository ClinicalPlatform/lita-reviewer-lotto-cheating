require_relative '../model'

module Lita::Handlers::Reviewer
  class BaseModel
    def self.inherited(child)
      Model.list << child
    end
  end
end
