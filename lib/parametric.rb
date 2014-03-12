require "parametric/version"

module Parametric

  def self.included(base)
    base.send(:attr_reader, :params)
    base.extend ClassMethods
  end

  def initialize(raw_params = {})
    @params = _reduce(raw_params)
  end

  def available_params
    @available_params ||= params.each_with_object({}) do |(k,v),memo|
      memo[k] = v if Utils.present?(v)
    end
  end

  protected

  class Policy
    def initialize(value, options, decorated = nil)
      @value, @options = value, options
      @decorated = decorated
    end

    def wrap(decoratedClass)
      decoratedClass.new(@value, @options, self)
    end

    def value
      Array(@value)
    end

    protected
    attr_reader :decorated, :options
  end

  class DefaultPolicy < Policy
    def value
      v = decorated.value
      v.any? ? v : Array(options[:default])
    end
  end

  class MultiplePolicy < Policy
    OPTION_SEPARATOR = /\s*,\s*/.freeze

    def value
      v = decorated.value.first
      v = v.split(options.fetch(:separator, OPTION_SEPARATOR)) if v.is_a?(String)
      Array(v)
    end
  end

  class SinglePolicy < Policy
    def value
      decorated.value.first
    end
  end

  class OptionsPolicy < Policy
    def value
      decorated.value.each_with_object([]){|a,arr| 
        arr << a if options[:options].include?(a)
      }
    end
  end

  class MatchPolicy < Policy
    def value
      decorated.value.each_with_object([]){|a,arr| 
        arr << a if a.to_s =~ options[:match]
      }
    end
  end

  def _reduce(raw_params)
    self.class._allowed_params.each_with_object({}) do |(key,options),memo|
      policy = Policy.new(raw_params[key], options)
      policy = policy.wrap(MultiplePolicy)  if options[:multiple]
      policy = policy.wrap(OptionsPolicy)   if options[:options]
      policy = policy.wrap(MatchPolicy)     if options[:match]
      policy = policy.wrap(DefaultPolicy)   if options.has_key?(:default)
      policy = policy.wrap(SinglePolicy)    unless options[:multiple]

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
