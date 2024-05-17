# frozen_string_literal: true

require 'parametric/v2/steppable'

module Parametric
  module V2
    class Step
      include Steppable

      attr_reader :metadata

      def initialize(callable = nil, metadata: DEFAULT_METADATA, &block)
        @metadata = callable.respond_to?(:metadata) ? callable.metadata : metadata
        @callable = callable || block
        @type = @callable.respond_to?(:new) ? @callable : @callable.class
      end

      def inspect
        %(Step[#{metadata.map { |(k,v)| "#{k}:#{v}" }.join(', ')}])
      end

      def ast
        [:leaf, metadata, []]
      end

      private def _call(result)
        @callable.call(result)
      end
    end
  end
end
