# frozen_string_literal: true

require 'bigdecimal'

module Parametric
  module V2
    class AST
      include Steppable

      attr_reader :ast

      def initialize(steppable, ast)
        if !ast.is_a?(::Array) \
          || ast.size != 3 \
          || !ast[0].is_a?(::Symbol) \
          || !ast[1].is_a?(::Hash) \
          || !ast[2].is_a?(::Array)
          raise ArgumentError, "expected an Array<Symbol, Hash, Array>, but got #{ast.inspect}"
        end

        @steppable = steppable
        @ast = ast
      end

      def call(result) = @steppable.call(result)
    end
  end
end
