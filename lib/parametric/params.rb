require 'ostruct'
module Parametric

  class ParamsHash < Hash
    def flat(separator = ',')
      self.each_with_object({}) do |(k,v),memo|
        memo[k] = Utils.value(v, separator)
      end
    end
  end

  module Params

    def self.included(base)
      base.send(:attr_reader, :params)
      base.extend DSL
    end

    def initialize(raw_params = {})
      @params = _reduce(raw_params)
    end

    def available_params
      @available_params ||= params.each_with_object(ParamsHash.new) do |(k,v),memo|
        if Utils.present?(v)
          memo[k] = v.respond_to?(:available_params) ? v.available_params : v
        end
      end
    end

    def schema
      @schema ||= params.each_with_object({}) do |(k,v),memo|
        is_nested = v.kind_of?(Parametric::Hash)
        attrs = self.class._allowed_params[k].dup
        attrs[:value] = is_nested ? v : Utils.value(v)
        attrs[:schema] = v.schema if is_nested
        memo[k] = OpenStruct.new(attrs)
      end
    end

    protected

    def _reduce(raw_params)
      self.class._allowed_params.each_with_object(ParamsHash.new) do |(key,options),memo|
        policy = Policies::Policy.new((raw_params.has_key?(key) ? raw_params[key] : []), options)
        policy = policy.wrap(Policies::CoercePolicy)    if options[:coerce]
        policy = policy.wrap(Policies::NestedPolicy)    if options[:nested]
        policy = policy.wrap(Policies::MultiplePolicy)  if options[:multiple]
        policy = policy.wrap(Policies::OptionsPolicy)   if options[:options]
        policy = policy.wrap(Policies::MatchPolicy)     if options[:match]
        policy = policy.wrap(Policies::ValidatorPolicy) if options[:validator]
        policy = policy.wrap(Policies::DefaultPolicy)   if options.has_key?(:default)
        policy = policy.wrap(Policies::SinglePolicy)    unless options[:multiple]
        memo[key] = policy.value
      end
    end

    module DSL
      def _allowed_params
        @allowed_params ||= {}
      end

      def param(field_name, label = '', opts = {}, &block)
        opts[:label] = label
        if block_given?
          nested = Class.new(Parametric::Hash)
          nested.instance_eval &block
          opts[:nested] = nested
        end
        _allowed_params[field_name] = opts
      end
    end

  end

end
