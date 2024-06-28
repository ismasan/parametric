# frozen_string_literal: true

require 'parametric/v2/steppable'

module Parametric
  module V2
    class Step
      include Steppable

      attr_reader :_metadata

      def initialize(callable = nil, &block)
        @_metadata = callable.respond_to?(:metadata) ? callable.metadata : BLANK_HASH
        @callable = callable || block
        freeze
      end

      def call(result)
        @callable.call(result)
      end
    end
  end
end
