# frozen_string_literal: true

module Parametric
  module V2
    class Schema
      def initialize(registry: Types, &block)
        @_schema = {}
        @registry = registry
        @_hash = Types::Hash
        setup(&block) if block_given?
      end

      def setup(&block)
        case block.arity
        when 1
          yield self
        when 0
          self.instance_eval(&block)
        else
          raise ArgumentError, "#{self.class} expects a block with 0 or 1 argument, but got #{block.arity}"
        end
        @_hash = Types::Hash.schema(@_schema)
        freeze
      end

      def metadata
        _hash.metadata
      end

      def call(value = BLANK_HASH)
        _hash.call(value)
      end

      def freeze
        super
        @_schema.freeze
        self
      end

      def field(key)
        _schema[Key.new(key)] = Field.new(registry:)
      end

      def field?(key)
        _schema[Key.new(key, optional: true)] = Field.new(registry:)
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

      def &(other)
        self.class.new(registry:).schema(_hash & other._hash)
      end

      alias merge &

      protected

      attr_reader :_hash

      private

      attr_reader :_schema, :registry

      class SchemaArray
        def initialize(registry:)
          @registry = registry
          @_type = Types::Array
        end

        def schema(sc = nil, &block)
          sc ||= Types::Schema.new(registry:, &block)
          @_type = @_type.of(sc)
          self
        end

        def rule(...)
          @_type = @_type.rule(...)
          self
        end

        def of(*args, &block)
          schema(*args, &block)
        end

        def call(result)
          _type.call(result)
        end

        private

        attr_reader :registry, :_type
      end

      class Field
        extend Forwardable

        attr_reader :_type

        def_delegators :_type, :call, :metadata
        alias meta_data metadata # bw compatibility

        def initialize(registry: Types)
          @registry = registry
          @_type = Types::Any
        end

        def type(type_symbol)
          if type_symbol.is_a?(Steppable)
            @_type = type_symbol
            return self
          end

          if type_symbol == :hash
            @_type = Types::Schema.new(registry: registry)
          elsif type_symbol == :array
            @_type = SchemaArray.new(registry: registry)
          else
            @_type = registry[type_symbol]
          end
          self
        end

        def of(element_type)
          raise ArgumentError, 'expected an Array type' unless _type.is_a?(SchemaArray)

          @_type = @_type.of(element_type)
          self
        end

        def schema(...)
          @_type = @_type.schema(...)
          self
        end

        def policy(*args)
          @_type = case args
          in [::Symbol => pl] # policy(:email)
            @_type >> registry[pl]
          in [Steppable => pl] # policy(Types::Email)
            @_type >> pl
          in [::Hash => rules] # policy(gt: 20, lt: 100)
            @_type.rule(rules)
          in [::Symbol => rule_name, Object => rule_matcher] # policy(:gt, 20)
            @_type.rule(rule_name => rule_matcher)
          else
            raise ArgumentError, "expected #{self.class}#policy(Symbol | Step) or #{self.class}#policy(Symbol, matcher)"
          end
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
          policy(:included_in, opts)
        end

        def declared
          # Halt pipeline if value is undefined
          @_type = Types::Nothing.not | @_type
          self
        end

        def optional
          @_type = Types::Nil.not | @_type
          self
        end

        def present
          policy(:present)
        end

        def required
          @_type = Types::Nothing.halt(error: 'is required') >> @_type
          self
        end

        def inspect
          @_type.inspect
        end

        private

        attr_reader :registry
      end
    end
  end
end
