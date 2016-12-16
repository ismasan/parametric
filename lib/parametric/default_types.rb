require "date"

module Parametric
  # type coercions
  Parametric.policy :integer do
    coerce do |v, k, c|
      v.to_i
    end

    meta_data do
      {type: :integer}
    end
  end

  Parametric.policy :number do
    coerce do |v, k, c|
      v.to_f
    end

    meta_data do
      {type: :number}
    end
  end

  Parametric.policy :string do
    coerce do |v, k, c|
      v.to_s
    end

    meta_data do
      {type: :string}
    end
  end

  Parametric.policy :boolean do
    coerce do |v, k, c|
      !!v
    end

    meta_data do
      {type: :boolean}
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

    meta_data do
      {type: :array}
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

    meta_data do
      {type: :object}
    end
  end

  Parametric.policy :split do
    coerce do |v, k, c|
      v.kind_of?(Array) ? v : v.to_s.split(/\s*,\s*/)
    end

    meta_data do
      {type: :array}
    end
  end

  Parametric.policy :datetime do
    coerce do |v, k, c|
      DateTime.parse(v.to_s)
    end

    meta_data do
      {type: :datetime}
    end
  end
end
