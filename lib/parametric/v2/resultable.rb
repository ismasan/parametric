# frozen_string_literal: true

module Parametric
  module V2
    module Resultable
      def success?
        true
      end

      def halt?
        false
      end

      def map(fn)
        fn.call(self)
      end
    end
  end
end
