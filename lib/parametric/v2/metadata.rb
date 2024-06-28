# frozen_string_literal: true

module Parametric
  module V2
    class Metadata
      include Steppable

      attr_reader :metadata

      def initialize(metadata)
        @metadata = metadata
      end

      def call(result) = result
    end
  end
end
