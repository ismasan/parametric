module Parametric
  # type coercions
  Parametric.policy :integer do
    coerce do |v, k, c|
      v.to_i
    end
  end

  Parametric.policy :number do
    coerce do |v, k, c|
      v.to_f
    end
  end

  Parametric.policy :string do
    coerce do |v, k, c|
      v.to_s
    end
  end

  Parametric.policy :boolean do
    coerce do |v, k, c|
      !!v
    end
  end

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

  Parametric.policy :split do
    coerce do |v, k, c|
      v.kind_of?(Array) ? v : v.to_s.split(/\s*,\s*/)
    end
  end
end
