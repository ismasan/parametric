# frozen_string_literal: true

require 'forwardable'
require 'parametric/v2/json_schema_visitor'

module Parametric
  module V2
    class Schema
      include Steppable

      def self.wrap(sc = nil, &block)
        raise ArgumentError, 'expected a block or a schema' if sc.nil? && !block_given?

        if sc
          raise ArgumentError, 'expected a Steppable' unless sc.is_a?(Steppable)

          return sc
        end

        new(&block)
      end

      attr_reader :fields

      def initialize(hash = Types::Hash, &block)
        @pipeline = Types::Any
        @before = Types::Any
        @after = Types::Any
        @_schema = {}
        @_hash = hash
        @fields = SymbolAccessHash.new({})

        setup(&block) if block_given?

        finish
      end

      def before(callable = nil, &block)
        @before >>= callable || block
        self
      end

      def after(callable = nil, &block)
        @after >>= callable || block
        self
      end

      def ast = _hash.ast

      def json_schema
        V2::JSONSchemaVisitor.call(ast).to_h
      end

      def call(result)
        @pipeline.call(result)
      end

      private def setup(&block)
        case block.arity
        when 1
          yield self
        when 0
          instance_eval(&block)
        else
          raise ::ArgumentError, "#{self.class} expects a block with 0 or 1 argument, but got #{block.arity}"
        end
        @_hash = Types::Hash.schema(@fields.transform_values(&:_type))
        self
      end

      private def finish
        @pipeline = @before.freeze >> @_hash.freeze >> @after.freeze
        @_schema.clear.freeze
        freeze
      end

      def field(key)
        key = Key.new(key.to_sym)
        @fields[key] = Field.new(key)
      end

      def field?(key)
        key = Key.new(key.to_sym, optional: true)
        @fields[key] = Field.new(key)
      end

      def +(other)
        self.class.new(_hash + other._hash)
      end

      def &(other)
        self.class.new(_hash & other._hash)
      end

      def merge(other = nil, &block)
        other = self.class.wrap(other, &block)
        self + other
      end

      protected

      attr_reader :_hash

      private

      attr_reader :_schema

      class SymbolAccessHash < SimpleDelegator
        def [](key)
          __getobj__[Key.wrap(key)]
        end
      end

      class Field
        include Callable

        attr_reader :_type, :key

        def initialize(key)
          @key = key.to_sym
          @_type = Types::Any
        end

        def ast = _type.ast
        def call(result) = _type.call(result)

        def type(steppable)
          unless steppable.respond_to?(:call)
            raise ArgumentError,
                  "expected a Parametric type, but got #{steppable.inspect}"
          end

          @_type >>= steppable
          self
        end

        def schema(...)
          @_type >>= Schema.wrap(...)
          self
        end

        def array(...)
          @_type >>= Types::Array[Schema.wrap(...)]
          self
        end

        def default(v, &block)
          @_type = @_type.default(v, &block)
          self
        end

        def meta(md = nil)
          @_type = @_type.meta(md) if md
          self
        end

        def options(opts)
          @_type = @_type.rule(included_in: opts)
          self
        end

        def optional
          @_type = Types::Nil | @_type
          self
        end

        def present
          @_type = @_type.present
          self
        end

        def required
          @_type = Types::Nothing.halt(error: 'is required') >> @_type
          self
        end

        def rule(...)
          @_type = @_type.rule(...)
          self
        end

        def inspect
          "#{self.class}[#{@_type.inspect}]"
        end

        private

        attr_reader :registry
      end
    end
  end
end
