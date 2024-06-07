# frozen_string_literal: true

require 'parametric/v2/metadata_visitor'

module Parametric
  module V2
    class UndefinedClass
      def inspect
        %(Undefined)
      end
    end

    TypeError = Class.new(::TypeError)
    Undefined = UndefinedClass.new.freeze

    BLANK_STRING = ''
    BLANK_ARRAY = [].freeze
    BLANK_HASH = {}.freeze
    BLANK_RESULT = Result.wrap(Undefined)

    module Callable
      def metadata
        MetadataVisitor.call(ast)
      end

      def resolve(value = Undefined)
        call(Result.wrap(value))
      end

      def cast(value)
        result = resolve(value)
        raise TypeError, result.error if result.halt?

        result.value
      end

      def call(result)
        raise NotImplementedError, "Implement #call(Result) => Result in #{self.class}"
      end
    end

    module Steppable
      include Callable

      def self.wrap(callable)
        if callable.is_a?(Steppable)
          callable
        elsif callable.respond_to?(:call)
          Step.new(callable)
        else
          StaticClass.new(callable)
        end
      end

      attr_reader :name

      class Name
        def initialize(name)
          @name = name
        end

        def to_s = @name

        def set(n)
          @name = n
          self
        end
      end

      def freeze
        return self if frozen?

        @name = Name.new(self.class.name)
        super
      end

      def inspect = name.to_s

      def ast
        raise NotImplementedError, "Implement #ast in #{self.class}"
      end

      def defer(definition = nil, &block)
        Deferred.new(definition || block)
      end

      def >>(other)
        And.new(self, Steppable.wrap(other))
      end

      def |(other)
        Or.new(self, Steppable.wrap(other))
      end

      class Transform
        include Steppable

        def initialize(target_type, callable)
          @target_type = target_type
          @callable = callable
        end

        def ast
          [:transform, { type: @target_type }, []]
        end

        def call(result)
          result.success(@callable.call(result.value))
        end
      end

      def transform(target_type, callable = nil, &block)
        self >> Transform.new(target_type, callable || block)
      end

      def check(error = 'did not pass the check', &block)
        a_check = lambda { |result|
          block.call(result.value) ? result : result.halt(error:)
        }

        self >> a_check
      end

      class Metadata
        include Steppable

        attr_reader :metadata

        def initialize(metadata)
          @metadata = metadata
        end

        def ast
          [:metadata, metadata, []]
        end

        def call(result) = result
      end

      def meta(data = {})
        self >> Metadata.new(data)
      end

      def not(other = self)
        Not.new(other)
      end

      def halt(error: nil)
        Not.new(self, error:)
      end

      def value(val)
        self >> Types::Value[val]
      end

      def [](val) = value(val)

      def default(val = Undefined, &block)
        # TODO: Default needs a type if given a block
        val_type = val == Undefined ? Types::Any.transform(::String, &block) : Types::Static[val]
        ((Types::Nothing >> val_type) | self).with_ast(
          [:default, { default: val }, [ast]]
        )
      end

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

      def with_ast(a)
        AST.new(self, a)
      end

      def optional
        Types::Nil | self
      end

      def present
        Types::Present >> self
      end

      def options(opts = [])
        rule(included_in: opts)
      end

      def rule(*args)
        specs = case args
                in [::Symbol => rule_name, value]
                  { rule_name => value }
                in [::Hash => rules]
                  rules
                else
                  raise ArgumentError, "expected 1 or 2 arguments, but got #{args.size}"
                end

        self >> Rules.new(specs, metadata[:type])
      end

      def match(pattern)
        rule(match: pattern)
      end

      def is_a(klass)
        rule(is_a: klass)
      end

      def coerce(type, coercion = nil, &block)
        coercion ||= block
        step = lambda { |result|
          if type === result.value
            result.success(coercion.call(result.value))
          else
            result.halt(error: "%s can't be coerced" % result.value.inspect)
          end
        }
        self >> step
      end

      def constructor(cns, factory_method = :new, &block)
        block ||= ->(value) { cns.send(factory_method, value) }
        (self >> ->(result) { result.success(block.call(result.value)) }).with_ast(
          [:constructor, { constructor: cns, factory_method: }, [ast]]
        )
      end

      def pipeline(&block)
        Pipeline.new(self, &block)
      end

      def to_s
        inspect
      end
    end
  end
end

require 'parametric/v2/deferred'
