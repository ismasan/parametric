require "parametric/version"

module Parametric

  OPTION_SEPARATOR = /\s*,\s*/.freeze

  def self.included(base)
    base.send(:attr_reader, :params)
    base.extend ClassMethods
  end

  def initialize(raw_params = {})
    @params = _reduce(raw_params)
  end

  protected

  class NullPolicy
    attr_reader :value
    def initialize(value, options)
      @value = value
    end
  end

  class Policy
    def initialize(value, options, decorated = NullPolicy.new(value, options))
      @value, @options = value, options
      @decorated = decorated
    end

    def wrap(decoratedClass)
      decoratedClass.new(@value, @options, self)
    end

    def value
      decorated.value
    end

    protected
    attr_reader :decorated, :options
  end

  class DefaultPolicy < Policy
    def value
      v = decorated.value
      if v.is_a?(Array)
        v.any? ? v : Array(options[:default])
      else
        Utils.present?(v) ? v : options[:default]
      end
    end
  end

  class MultiplePolicy < Policy
    def value
      v = decorated.value
      v = v.split(options.fetch(:separator, OPTION_SEPARATOR)) if v.is_a?(String)
      Array(v)
    end
  end

  class OptionsPolicy < Policy
    def value
      v = decorated.value
      if v.is_a?(Array)
        v.each_with_object([]){|a,arr| arr << a if options[:options].include?(a)}
      else
        options[:options].include?(v) ? v : nil
      end
    end
  end

  class MatchPolicy < Policy
    def value
      v = decorated.value
      if v.is_a?(Array)
        v.each_with_object([]){|a,arr| arr << a if a.to_s =~ options[:match]}
      else
        v.to_s =~ options[:match] ? v : nil
      end
    end
  end

  def _reduce(raw_params)
    self.class._allowed_params.each_with_object({}) do |(key,options),memo|
      policy = Policy.new(raw_params[key], options)
      policy = policy.wrap(MultiplePolicy) if options[:multiple]
      policy = policy.wrap(OptionsPolicy) if options[:options]
      policy = policy.wrap(MatchPolicy) if options[:match]
      policy = policy.wrap(DefaultPolicy) if Utils.present?(options[:default])

      memo[key] = policy.value
    end
  end

  module ClassMethods
    def _allowed_params
      @allowed_params ||= {}
    end

    def param(field_name, prompt = '', opts = {})
      opts[:prompt] = prompt
      _allowed_params[field_name] = opts
    end

  end

  module Utils
    def self.present?(value)
      case value
      when String
        value.strip != ''
      when Array, Hash
        value.any?
      else
        !value.nil?
      end
    end
  end
end
