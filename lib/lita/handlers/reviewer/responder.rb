module Lita::Handlers::Reviewer
  class Responder
    class << self
      def list
        @responders ||= []
      end
    end

    require_relative 'responders/chat_responder'
    require_relative 'responders/github_comment_responder'
    require_relative 'responders/github_status_check_responder'
  end
end
