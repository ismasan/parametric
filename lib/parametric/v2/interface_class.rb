# frozen_string_literal: true

require 'parametric/v2/steppable'

module Parametric
  module V2
    class InterfaceClass
      include Steppable

      def initialize(method_names = [])
        @method_names = method_names
      end

      def of(*args)
        case args
        in Array => symbols if symbols.all? { |s| s.is_a?(::Symbol) }
          self.class.new(symbols)
        else
          raise ::ArgumentError, "unexpected value to Types::Interface#of #{args.inspect}"
        end
      end

      alias_method :[], :of

      def ast
        [:interface, { method_names: @method_names }, BLANK_ARRAY]
      end

      def call(result)
        obj = result.value
        missing_methods = @method_names.reject { |m| obj.respond_to?(m) }
        return result.halt(error: "missing methods: #{missing_methods.join(', ')}") if missing_methods.any?

        result
      end
    end
  end
end
