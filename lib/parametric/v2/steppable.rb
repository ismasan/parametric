# frozen_string_literal: true

require 'parametric/v2/metadata_visitor'

module Parametric
  module V2
    class UndefinedClass
      def inspect
        %(Undefined)
      end

      def to_s = inspect
      def node_name = :undefined
    end

    TypeError = Class.new(::TypeError)
    Undefined = UndefinedClass.new.freeze

    BLANK_STRING = ''
    BLANK_ARRAY = [].freeze
    BLANK_HASH = {}.freeze
    BLANK_RESULT = Result.wrap(Undefined)

    module Callable
      def metadata
        MetadataVisitor.call(self)
      end

      def resolve(value = Undefined)
        call(Result.wrap(value))
      end

      def cast(value)
        result = resolve(value)
        raise TypeError, result.errors if result.halt?

        result.value
      end

      def call(result)
        raise NotImplementedError, "Implement #call(Result) => Result in #{self.class}"
      end
    end

    module Steppable
      include Callable

      def self.included(base)
        nname = base.name.split('::').last
        nname.gsub!(/([a-z\d])([A-Z])/,'\1_\2')
        nname.downcase!
        nname.gsub!(/_class$/, '')
        nname = nname.to_sym
        base.define_method(:node_name) { nname }
      end

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

        @name = Name.new(_inspect)
        super
      end

      private def _inspect = self.class.name

      def inspect = name.to_s

      def node_name = self.class.name.split('::').last.to_sym

      def defer(definition = nil, &block)
        Deferred.new(definition || block)
      end

      def >>(other)
        And.new(self, Steppable.wrap(other))
      end

      def |(other)
        Or.new(self, Steppable.wrap(other))
      end

      def transform(target_type, callable = nil, &block)
        self >> Transform.new(target_type, callable || block)
      end

      def check(errors = 'did not pass the check', &block)
        a_check = lambda { |result|
          block.call(result.value) ? result : result.halt(errors:)
        }

        self >> a_check
      end

      def meta(data = {})
        self >> Metadata.new(data)
      end

      def not(other = self)
        Not.new(other)
      end

      def halt(errors: nil)
        Not.new(self, errors:)
      end

      def value(val)
        self >> ValueClass.new(val)
      end

      def match(*args)
        self >> MatchClass.new(*args)
      end

      def [](val) = match(val)

      DefaultProc = proc do |callable|
        proc do |result|
          result.success(callable.call)
        end
      end

      def default(val = Undefined, &block)
        val_type = if val == Undefined
                     DefaultProc.call(block)
                   else
                     Types::Static[val]
                   end

        self | (Types::Undefined >> val_type)
      end

      class Node
        include Steppable

        attr_reader :node_name, :type, :attributes

        def initialize(node_name, type, attributes = BLANK_HASH)
          @node_name = node_name
          @type = type
          @attributes = attributes
          freeze
        end

        def call(result) = type.call(result)
      end

      def as_node(node_name, metadata = BLANK_HASH)
        Node.new(node_name, self, metadata)
      end

      def nullable
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

      def is_a(klass)
        rule(is_a: klass)
      end

      def ===(other)
        case other
        when Steppable
          other == self
        else
          resolve(other).success?
        end
      end

      def coerce(type, coercion = nil, &block)
        coercion ||= block
        step = lambda { |result|
          if type === result.value
            result.success(coercion.call(result.value))
          else
            result.halt(errors: "%s can't be coerced" % result.value.inspect)
          end
        }
        self >> step
      end

      def constructor(cns, factory_method = :new, &block)
        self >> Constructor.new(cns, factory_method:, &block)
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
require 'parametric/v2/transform'
require 'parametric/v2/constructor'
require 'parametric/v2/metadata'
