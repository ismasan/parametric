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
          raise ArgumentError, 'expected a schema' unless sc.is_a?(Schema)
          return sc
        end

        new(&block)
      end

      attr_reader :fields

      def initialize(&block)
        @_schema = {}
        @_hash = Types::Hash
        @fields = {}

        if block_given?
          setup(&block)
          finish
        end
      end

      def ast = _hash.ast

      def json_schema
        V2::JSONSchemaVisitor.call(ast).to_h
      end

      private def setup(&block)
        case block.arity
        when 1
          yield self
        when 0
          self.instance_eval(&block)
        else
          raise ::ArgumentError, "#{self.class} expects a block with 0 or 1 argument, but got #{block.arity}"
        end
        @_hash = Types::Hash.schema(@_schema)
        self
      end

      def call(value = BLANK_HASH)
        _hash.call(value)
      end

      private def finish
        @fields = SymbolAccessHash.new(_hash.to_h)
        @_schema.clear.freeze
        @_hash.freeze
      end

      def field(key)
        key = key.to_sym
        _schema[Key.new(key)] = Field.new(key)
      end

      def field?(key)
        key = key.to_sym
        _schema[Key.new(key, optional: true)] = Field.new(key)
      end

      def schema(sc = nil, &block)
        if sc
          @_hash = sc
          freeze
          self
        else
          setup(&block) if block_given?
        end
      end

      def +(other)
        self.class.new.schema(_hash + other._hash)
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
        extend Forwardable

        attr_reader :_type, :key

        def_delegators :_type, :call

        def initialize(key)
          @key = key
          @_type = Types::Any
        end

        def ast = _type.ast

        def type(steppable)
          raise ArgumentError, "expected a Parametric type, but got #{steppable.inspect}" unless steppable.respond_to?(:call)

          @_type = @_type >> steppable
          self
        end

        def schema(...)
          @_type = @_type >> Schema.wrap(...)
          self
        end

        def array(...)
          @_type = @_type >> SchemaArray.new(Schema.wrap(...))
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

        def inspect
          "#{self.class}[#{@_type.inspect}]"
        end

        private

        attr_reader :registry
      end

      class SchemaArray
        def initialize(schema)
          @schema = schema
          @_type = Types::Array[schema]
        end

        def call(result)
          _type.call(result)
        end

        private

        attr_reader :_type
      end
    end
  end
end
