require 'active_support/descendants_tracker'

module Lita::Handlers::ReviewerLottoCheating
  class Model
    extend ActiveSupport::DescendantsTracker

    class << self
      alias :list :descendants
    end
  end
end
