module Lita::Handlers::Reviewer
  class Registory
    class << self
      def models
        @models ||= []
      end

      def responders
        @responders ||= []
      end
    end
  end
end
