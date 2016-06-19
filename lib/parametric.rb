require "parametric/version"
require 'ostruct'

module Parametric

  def self.registry
    @registry ||= Registry.new
  end

  class BlockValidator
    def self.message(&block)
      @message_block = block if block_given?
      @message_block
    end

    def self.validate(&validate_block)
      @validate_block = validate_block if block_given?
      @validate_block
    end

    attr_reader :message

    def initialize(*args)
      @args = args
      @message = 'is invalid'
      @validate_block = self.class.validate || ->(*args) { true }
    end

    def valid?(key, value, payload)
      args = (@args + [value])
      @message = self.class.message.call(*args) if self.class.message
      @validate_block.call(*args)
    end

  end

  class Registry
    attr_reader :filters, :validators

    def initialize
      @filters = {}
      @validators = {}
    end

    def validator(name, vdtor = nil, &block)
      obj = if vdtor
        vdtor
      else
        klass = Class.new(BlockValidator)
        klass.instance_eval &block
        klass
      end

      validators[name] = obj
      self
    end

    def filter(name, f)
      filters[name] = f
    end
  end

  def self.validator(name, vdtor = nil, &block)
    registry.validator name, vdtor, &block
  end

  def self.filter(name, f)
    registry.filter name, f
  end

  class OptionsPolicy
    def initialize(opts)
      @opts = Array(opts)
    end

    def ok?(payload, key, value)
      @opts.include? value
    end
  end

  class Field
    attr_reader :key, :meta_data

    def initialize(key, registry = Parametric.registry)
      @key = key
      @filters = []
      @validators = []
      @registry = registry
      @default_block = nil
      @meta_data = {}
      @policies = []
    end

    def meta(hash = nil)
      @meta_data = @meta_data.merge(hash) if hash.is_a?(Hash)
      self
    end

    def default(value)
      meta default: value
      @default_block = (value.respond_to?(:call) ? value : ->(key, payload, context) { value })
      self
    end

    def type(t)
      meta type: t
      filter t
      validate(t) if registry.validators.key?(t)
      self
    end

    def required
      meta required: true
      validate :required
    end

    def options(opts)
      meta options: opts
      policies << OptionsPolicy.new(opts)
      validate :options, opts
    end

    def validate(k, *args)
      k = if k.is_a?(Symbol)
        ft = registry.validators[k]
        raise "No validator for #{k.inspect}" unless ft
        ft = ft.new(*args) if ft.respond_to?(:new)
        ft
      else
        k
      end

      validators << k
      self
    end

    def filter(f, *args)
      f = if f.is_a?(Symbol)
        ft = registry.filters[f]
        raise "No filter for #{f.inspect}" unless ft
        ft = ft.new(*args) if ft.respond_to?(:new)
        ft
      else
        f.respond_to?(:new) ? f.new(*args) : f
      end

      filters << f
      self
    end

    def schema(sc = nil, &block)
      sc = (sc ? sc : Schema.new(&block))
      meta schema: sc
      filter sc
    end

    def resolve(payload, context, &block)
      if payload_has_key?(payload, key)
        value = payload[key] # might be nil
        result = if value.is_a?(Array)
          resolve_array value, context
        else
          resolve_value value, context
        end

        if run_validations(key, result, payload, context)
          yield result if block_given?
          result
        end
      elsif has_default?
        result = default_block.call(key, payload, context)
        if run_validations(key, result, payload, context)
          yield result if block_given?
          result
        end
      else
        run_validations(key, nil, payload, context)
        nil
      end
    end

    protected
    attr_reader :filters, :validators, :registry, :default_block, :policies

    def has_default?
      !!default_block
    end

    def resolve_array(arr, context)
      arr.map.with_index do |v, idx|
        ctx = context.sub(idx)
        resolve_value v, ctx
      end
    end

    def resolve_value(value, context)
      filters.reduce(value) do |val, f|
        f.call(val, key, context)
      end
    end

    def run_validations(key, result, payload, context)
      validators.all? do |v|
        r = v.valid?(key, result, payload)
        context.add_error(v.message) unless r
        r
      end
    end

    def payload_has_key?(payload, key)
      payload.kind_of?(Hash) && payload.key?(key) && all_policies_ok?(payload, key)
    end

    def all_policies_ok?(payload, key)
      policies.all? do |po|
        po.ok?(payload, key, payload[key])
      end
    end
  end

  class Results
    attr_reader :output, :errors

    def initialize(output, errors)
      @output, @errors = output, errors
    end

    def valid?
      !errors.keys.any?
    end
  end

  class Schema
    def initialize(&block)
      @fields = []
      self.instance_eval(&block) if block_given?
    end

    def schema
      fields.each_with_object({}) do |field, obj|
        meta = field.meta_data.dup
        sc = meta.delete(:schema)
        meta[:schema] = sc.schema if sc
        obj[field.key] = OpenStruct.new(meta)
      end
    end

    def field(key)
      f = key.kind_of?(Field) ? key : Field.new(key)
      fields << f
      f
    end

    def resolve(payload)
      context = Context.new
      output = call(payload, nil, context)
      Results.new(output, context.errors)
    end

    def call(val, _, context)
      fields.each_with_object({}) do |field, m|
        field.resolve(val, context.sub(field.key)) do |r|
          m[field.key] = r
        end
      end
    end

    protected
    attr_reader :fields
  end

  class Required
    attr_reader :message

    def initialize
      @message = 'is missing'
    end

    def valid?(key, value, payload)
      !!value
    end
  end

  class Format
    attr_reader :message

    def initialize(fmt)
      @message = 'invalid format'
      @fmt = fmt
    end

    def valid?(key, value, payload)
      value.to_s =~ @fmt
    end
  end

  class Top
    attr_reader :errors

    def initialize
      @errors = {}
    end

    def add_error(key, msg)
      errors[key] ||= []
      errors[key] << msg
    end
  end

  class Context
    def initialize(path = nil, top = Top.new)
      @top = top
      @path = Array(path).compact
    end

    def errors
      top.errors
    end

    def add_error(msg)
      top.add_error(string_path, msg)
    end

    def sub(key)
      self.class.new(path + [key], top)
    end

    protected
    attr_reader :path, :top

    def string_path
      path.reduce(['$']) do |m, segment|
        m << (segment.is_a?(Fixnum) ? "[#{segment}]" : ".#{segment}")
        m
      end.join
    end
  end

  module Params
    def self.included(base)
      base.extend DSL
    end

    attr_reader :params, :schema

    def initialize(payload)
      results = self.class.schema.resolve(payload)
      @params = results.output
      @schema = self.class.schema.schema
    end

    module DSL
      def schema
        @schema ||= Schema.new
      end

      def param(key, label, opts = {}, &block)
        f = Field.new(key).meta(label: label)
        f.default(opts[:default]) if opts[:default]
        f.type(opts[:type]) if opts[:type]
        f.required if opts[:required]
        f.validate(opts[:validate]) if opts[:validate]
        f.validate(:format, opts[:match]) if opts[:match]
        if opts[:coerce]
          f.filter(->(v, _, _){ opts[:coerce].call(v) })
        end
        if block_given?
          sub_schema = Class.new(SubParams, &block)
          f.schema sub_schema.schema
        end
        schema.field f
      end

    end
  end

  module TypedParams
    def self.included(base)
      base.send(:include, Params)
      base.extend(TypesDSL)
    end

    module TypesDSL
      def string(name, label, opts = {}, &block)
        param name, label, opts.merge(type: :string), &block
      end

      def integer(name, label, opts = {}, &block)
        param name, label, opts.merge(type: :integer), &block
      end

      def array(name, label, opts = {}, &block)
        param name, label, opts.merge(type: :array), &block
      end
    end
  end

  class SubParams
    include TypedParams
  end

  # type coercions
  Parametric.filter :integer, ->(v, k, c){ v.to_i }
  Parametric.filter :number, ->(v, k, c){ v.to_f }
  Parametric.filter :string, ->(v, k, c){ v.to_s }
  Parametric.filter :boolean, ->(v, k, c){ !!v }
  Parametric.filter :object, ->(v, k, c){ v }
  Parametric.filter :array, ->(v, k, c){ v }

  Parametric.filter :split, ->(v, k, c){ v.to_s.split(',') }

  Parametric.validator :required, Required
  Parametric.validator :format, Format
  Parametric.validator :email, Format.new(/\A[\w+\-.]+@[a-z\d\-]+(\.[a-z]+)*\.[a-z]+\z/i)
  Parametric.validator :gt do
    message do |num, actual|
      "must be greater than #{num}, but got #{actual}"
    end

    validate do |num, actual|
      actual.to_i > num.to_i
    end
  end

  Parametric.validator :options do
    message do |options, actual|
      "must be one of #{options.join(', ')}, but got #{actual}"
    end

    validate do |options, actual|
      [actual].flatten.all?{|v| options.include?(v)}
    end
  end
end
