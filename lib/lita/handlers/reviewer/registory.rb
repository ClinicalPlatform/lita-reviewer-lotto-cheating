module Lita::Handlers::Reviewer
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
