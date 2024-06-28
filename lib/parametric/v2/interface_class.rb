# frozen_string_literal: true

require 'parametric/v2/steppable'

module Parametric
  module V2
    class InterfaceClass
      include Steppable

      attr_reader :method_names

      def initialize(method_names = [])
        @method_names = method_names
        freeze
      end

      def of(*args)
        case args
        in Array => symbols if symbols.all? { |s| s.is_a?(::Symbol) }
          self.class.new(symbols)
        else
          raise ::ArgumentError, "unexpected value to Types::Interface#of #{args.inspect}"
        end
      end

      alias [] of

      def call(result)
        obj = result.value
        missing_methods = @method_names.reject { |m| obj.respond_to?(m) }
        return result.halt(errors: "missing methods: #{missing_methods.join(', ')}") if missing_methods.any?

        result
      end
    end
  end
end
