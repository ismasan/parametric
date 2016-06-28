module Parametric
  # type coercions
  Parametric.coercion :integer, ->(v, k, c){ v.to_i }
  Parametric.coercion :number, ->(v, k, c){ v.to_f }
  Parametric.coercion :string, ->(v, k, c){ v.to_s }
  Parametric.coercion :boolean, ->(v, k, c){ !!v }

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
