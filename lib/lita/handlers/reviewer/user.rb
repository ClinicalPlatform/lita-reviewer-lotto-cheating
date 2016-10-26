module Lita
  module Handlers
    class Reviewer < Handler
      class User
        USERS_KEY = 'users'

        attr_accessor :name
        attr_reader :redis

        def initialize(name, redis: nil)
          @name  = name
          @redis = redis || self.class.redis
        end

        def working_today?
          days = redis.smembers(key(:working_days))
                      .map(&:to_i)
          days.include?(DateTime.now.cwday)
        end

        def level
          redis.get(key(:level)).to_i
        end

        def screen_name
          "@#{name}"
        end

        private

        def key(field = nil)
          "#{USERS_KEY}:#{name}#{field&.to_s.prepend(':')}"
        end

        class << self
          attr_accessor :redis, :github

          def prepare(redis, *_args)
            @redis = redis
          end

          def list
            redis.smembers(USERS_KEY).map { |name| new(name) }
          end

          def to_text(users)
            users.map(&:name).join(', ')
          end
        end
      end
    end
  end
end
