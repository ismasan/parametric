# frozen_string_literal: true

require 'parametric/v2/steppable'

module Parametric
  module V2
    class Step
      include Steppable

      attr_reader :metadata

      def initialize(callable = nil, metadata: DEFAULT_METADATA, &block)
        @metadata = metadata
        @callable = callable || block
      end

      def inspect
        %(Step[#{metadata.map { |(k,v)| "#{k}:#{v}" }.join(', ')}])
      end

      private def _call(result)
        @callable.call(result)
      end
    end
  end
end
