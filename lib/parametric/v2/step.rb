# frozen_string_literal: true

require 'parametric/v2/steppable'

module Parametric
  module V2
    class Step
      include Steppable

      def initialize(callable = nil, &block)
        @_metadata = callable.respond_to?(:metadata) ? callable.metadata : BLANK_HASH
        @callable = callable || block
        @type = @callable.respond_to?(:new) ? @callable : @callable.class
      end

      def ast
        [:leaf, @_metadata, []]
      end

      def call(result)
        @callable.call(result)
      end
    end
  end
end
