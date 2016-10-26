module Lita
  module Handlers
    class Reviewer < Handler
      class Registory
        class << self
          def models
            @models ||= []
          end

          def responsers
            @responsers ||= []
          end
        end
      end
    end
  end
end
