module Lita::Handlers::Reviewer
  class Model
    class << self
      def list
        @models ||= []
      end
    end
  end
end
