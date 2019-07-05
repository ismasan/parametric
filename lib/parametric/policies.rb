module Parametric
  module Policies
    class Format
      attr_reader :message

      def initialize(fmt, msg = "invalid format")
        @message = msg
        @fmt = fmt
      end

      def eligible?(value, key, payload)
        payload.key?(key)
      end

      def coerce(value, key, context)
        value
      end

      def valid?(value, key, payload)
        !payload.key?(key) || !!(value.to_s =~ @fmt)
      end

      def meta_data
        {}
      end
    end
  end

  # Default validators
  EMAIL_REGEXP = /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z]+)*\.[a-z]+\z/i.freeze

  Parametric.policy :format, Policies::Format
  Parametric.policy :email, Policies::Format.new(EMAIL_REGEXP, 'invalid email')

  Parametric.policy :noop do
    eligible do |value, key, payload|
      true
    end
  end

  Parametric.policy :declared do
    eligible do |value, key, payload|
      payload.key? key
    end
  end

  Parametric.policy :declared_no_default do
    eligible do |value, key, payload|
      payload.key? key
    end

    meta_data do
      {skip_default: true}
    end
  end

  Parametric.policy :required do
    message do |*|
      "is required"
    end

    validate do |value, key, payload|
      payload.key? key
    end

    meta_data do
      {required: true}
    end
  end

  Parametric.policy :present do
    message do |*|
      "is required and value must be present"
    end

    validate do |value, key, payload|
      case value
      when String
        value.strip != ''
      when Array, Hash
        value.any?
      else
        !value.nil?
      end
    end

    meta_data do
      {present: true}
    end
  end

  Parametric.policy :gt do
    message do |num, actual|
      "must be greater than #{num}, but got #{actual}"
    end

    validate do |num, actual, key, payload|
      !payload[key] || actual.to_i > num.to_i
    end
  end

  Parametric.policy :lt do
    message do |num, actual|
      "must be less than #{num}, but got #{actual}"
    end

    validate do |num, actual, key, payload|
      !payload[key] || actual.to_i < num.to_i
    end
  end

  Parametric.policy :options do
    message do |options, actual|
      "must be one of #{options.join(', ')}, but got #{actual}"
    end

    eligible do |options, actual, key, payload|
      payload.key?(key)
    end

    validate do |options, actual, key, payload|
      !payload.key?(key) || ok?(options, actual)
    end

    meta_data do |opts|
      {options: opts}
    end

    def ok?(options, actual)
      [actual].flatten.all?{|v| options.include?(v)}
    end
  end
end
