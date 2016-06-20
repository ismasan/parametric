require "parametric/schema"
module Parametric
  class ConfigurationError < StandardError; end

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

    def present
      required.validate :present
    end

    def options(opts)
      meta options: opts
      validate :options, opts
    end

    def validate(key, *args)
      validators << lookup('validator', key, registry.validators, args)
      self
    end

    def filter(key, *args)
      filters << lookup('filter', key, registry.filters, args)
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
        r = v.valid?(result, key, payload)
        context.add_error(v.message) unless r
        r
      end
    end

    def payload_has_key?(payload, key)
      payload.kind_of?(Hash) && payload.key?(key) && all_guards_ok?(payload, key)
    end

    def all_guards_ok?(payload, key)
      validators.all? do |va|
        va.exists?(payload[key], key, payload)
      end
    end

    def lookup(set_name, key, set, args)
      obj = if key.is_a?(Symbol)
        o = set[key]
        raise ConfigurationError, "No #{set_name} for #{key.inspect}" unless o
        o
      else
        key
      end

      obj.respond_to?(:new) ? obj.new(*args) : obj
    end

  end

end
