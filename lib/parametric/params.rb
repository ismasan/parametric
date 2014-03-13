module Parametric

  module Params

    def self.included(base)
      base.send(:attr_reader, :params)
      base.extend DSL
    end

    def initialize(raw_params = {})
      @params = _reduce(raw_params)
    end

    def available_params
      @available_params ||= params.each_with_object({}) do |(k,v),memo|
        memo[k] = v if Utils.present?(v)
      end
    end

    def schema
      @schema ||= params.each_with_object({}) do |(k,v),memo|
        memo[k] = {
          value: Utils.value(v),
          label: self.class._allowed_params[k][:label],
          multiple: !!self.class._allowed_params[k][:multiple]
        }
        memo[k][:match] = self.class._allowed_params[k][:match].to_s if self.class._allowed_params[k].has_key?(:match)
        memo[k][:options] = self.class._allowed_params[k][:options] if self.class._allowed_params[k].has_key?(:options)
      end
    end

    protected

    def _reduce(raw_params)
      self.class._allowed_params.each_with_object({}) do |(key,options),memo|
        policy = Policies::Policy.new(raw_params[key], options)
        policy = policy.wrap(Policies::MultiplePolicy)  if options[:multiple]
        policy = policy.wrap(Policies::OptionsPolicy)   if options[:options]
        policy = policy.wrap(Policies::MatchPolicy)     if options[:match]
        policy = policy.wrap(Policies::DefaultPolicy)   if options.has_key?(:default)
        policy = policy.wrap(Policies::SinglePolicy)    unless options[:multiple]

        memo[key] = policy.value
      end
    end

    module DSL
      def _allowed_params
        @allowed_params ||= {}
      end

      def param(field_name, label = '', opts = {})
        opts[:label] = label
        _allowed_params[field_name] = opts
      end
    end

  end

end