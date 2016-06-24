module Parametric
  # type coercions
  Parametric.filter :integer, ->(v, k, c){ v.to_i }
  Parametric.filter :number, ->(v, k, c){ v.to_f }
  Parametric.filter :string, ->(v, k, c){ v.to_s }
  Parametric.filter :boolean, ->(v, k, c){ !!v }

  # type validations
  Parametric.policy :array do
    message do |actual|
      "expects an array, but got #{actual.inspect}"
    end

    validate do |value, key, payload|
      !payload.key?(key) || value.is_a?(Array)
    end
  end

  Parametric.policy :object do
    message do |actual|
      "expects a hash, but got #{actual.inspect}"
    end

    validate do |value, key, payload|
      !payload.key?(key) ||
        value.respond_to?(:[]) &&
        value.respond_to?(:key?)
    end
  end

end
