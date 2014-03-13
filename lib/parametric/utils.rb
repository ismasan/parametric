module Parametric
  module Utils
    def self.value(val)
      if val.nil?
        ''
      elsif val.is_a?(Array)
        val.join(',')
      else
        val
      end
    end

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