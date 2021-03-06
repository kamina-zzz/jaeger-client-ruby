# frozen_string_literal: true

module Jaeger
  module Samplers
    # Samples at most max_traces_per_second. The distribution of sampled
    # traces follows burstiness of the service, i.e. a service with uniformly
    # distributed requests will have those requests sampled uniformly as
    # well, but if requests are bursty, especially sub-second, then a number
    # of sequential requests can be sampled each second.
    class RateLimiting
      attr_reader :tags, :max_traces_per_second

      def initialize(max_traces_per_second: 10)
        update(max_traces_per_second: max_traces_per_second)
      end

      def update(max_traces_per_second:)
        if max_traces_per_second < 0.0
          raise "max_traces_per_second must not be negative, got #{max_traces_per_second}"
        end

        return false if max_traces_per_second == @max_traces_per_second

        @tags = {
          'sampler.type' => 'ratelimiting',
          'sampler.param' => max_traces_per_second
        }
        @max_traces_per_second = max_traces_per_second
        max_balance = [max_traces_per_second, 1.0].max

        if @rate_limiter
          @rate_limiter.update(
            credits_per_second: max_traces_per_second,
            max_balance: max_balance
          )
        else
          @rate_limiter = RateLimiter.new(
            credits_per_second: max_traces_per_second,
            max_balance: [max_traces_per_second, 1.0].max
          )
        end

        true
      end

      def sample(*)
        [@rate_limiter.check_credit(1.0), @tags]
      end
    end
  end
end
