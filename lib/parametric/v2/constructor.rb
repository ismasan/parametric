# frozen_string_literal: true

require 'parametric/v2/steppable'

module Parametric
  module V2
    class Constructor
      include Steppable

      attr_reader :type

      def initialize(type, factory_method: :new, &block)
        @type = type
        @block = block || ->(value) { type.send(factory_method, value) }
      end

      def call(result) = result.success(@block.call(result.value))
    end
  end
end
