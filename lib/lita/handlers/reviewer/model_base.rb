require_relative 'registory'

module Lita
  module Handlers
    class Reviewer < Handler
      class ModelBase
        def self.inherited(child)
          Registory.models << child
        end
      end
    end
  end
end

