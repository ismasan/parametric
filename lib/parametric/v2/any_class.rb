# frozen_string_literal: true

require 'parametric/v2/steppable'

module Parametric
  module V2
    class AnyClass
      include Steppable

      def call(result) = result
    end
  end
end
