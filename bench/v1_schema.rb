require 'parametric'
require 'money'
require 'monetize'

Parametric.policy(:nullable_money) do
  PARAMETRIC_MONEY_EXP = /(\W{1}|\w{3})?[\d+\,\.]/

  coerce do |value, _key, _context|
    money = case value
    when String
      value = value.strip
      if value.blank?
        nil
      elsif value =~ PARAMETRIC_MONEY_EXP
        Monetize.parse!(value.gsub(',', ''))
      else
        raise ArgumentError, "#{value} is not a monetary amount"
      end
    when Numeric
      Monetize.parse!(value.to_s)
    when Money
      value
    when NilClass
      nil
    else
      raise ArgumentError, "don't know how to coerce #{value.inspect} into Money"
    end

    raise ArgumentError, "expected #{Money.default_currency.name} as currency, but got #{money.currency.name}" if money && money.currency != Money.default_currency

    money
  end

  meta_data do
    { type: :number, config_type: :nullable_money }
  end
end

Parametric.policy(:nullable_date) do
  # rubocop:disable Style/RedundantBegin
  coerce do |value, _key, _context|
    begin
      value = value.to_s.strip
      value == '' ? nil : Date.parse(value)
    rescue Date::Error
      nil
    end
  end
  # rubocop:enable Style/RedundantBegin

  meta_data do
    { type: :date, config_type: :nullable_date }
  end
end

Parametric.policy :nullable_date_range do
  PARAMETRIC_DATE_EXP = /\A\d{4}-\d{2}-\d{2}\z/
  PARAMETRIC_DATE_INFINITY = 'infinity'
  PARAMETRIC_IS_DATE = ->(value) { value.is_a?(::Date) || (value.is_a?(::String) && value =~ PARAMETRIC_DATE_EXP) }
  PARAMETRIC_PARSE_DATE = ->(value) { value.is_a?(::Date) ? value : ::Date.parse(value) }

  validate do |value, _key, _context|
    if value.blank? || value.is_a?(Switcher::DateRange)
      true
    else
      value.is_a?(Hash) && !!(PARAMETRIC_IS_DATE.call(value[:min]) && (value[:max].nil? || PARAMETRIC_IS_DATE.call(value[:max] || value[:max] == PARAMETRIC_DATE_INFINITY)))
    end
  end

  coerce do |value, _key, _context|
    if value.is_a?(Switcher::DateRange)
      value
    elsif value.blank? || (value[:min].blank? && value[:max].blank?)
      nil
    else
      min = value[:min].present? ? PARAMETRIC_PARSE_DATE.call(value[:min]) : nil
      max = (value[:max].present? && value[:max] != PARAMETRIC_DATE_INFINITY) ? PARAMETRIC_PARSE_DATE.call(value[:max]) : nil
      Switcher::DateRange.new(min, max)
    end
  end

  meta_data do
    { type: :object, config_type: :nullable_date_range }
  end
end

Parametric.policy(:nullable_integer) do
  PARAMETRIC_INT_EXP = /^\d+$/.freeze

  coerce do |value, _key, _context|
    if value.to_s =~ PARAMETRIC_INT_EXP
      value.to_i
    else
      nil
    end
  end

  meta_data do
    { type: :integer, config_type: :nullable_integer }
  end
end

Parametric.policy(:nullable_number) do
  PARAMETRIC_FLOAT_EXP = /^\d+(\.\d+)?$/.freeze

  coerce do |value, _key, _context|
    if value.to_s =~ PARAMETRIC_FLOAT_EXP
      value.to_f
    else
      nil
    end
  end

  meta_data do
    { type: :number, config_type: :nullable_number }
  end
end

Parametric.policy :size do
  message do |opts, object|
    "must have size of #{opts}, but got #{object.size}"
  end

  validate do |opts, object, _key, _payload|
    size = object.size
    (opts[:min].nil? || size >= opts[:min]) && (opts[:max].nil? || size <= opts[:max])
  end
end

Parametric.policy(:nullable_string) do
  coerce do |value, _key, _context|
    if value.to_s.strip != ''
      value.to_s
    else
      nil
    end
  end

  meta_data do
    { type: :string, config_type: :nullable_string }
  end
end

module V1Schemas
  TERM = Parametric::Schema.new do
    field(:name).type(:string).default('')
    field(:url).type(:string).default('')
    field(:terms_text).type(:string).default('')
    field(:start_date).type(:nullable_date)
    field(:end_date).type(:nullable_date)
  end
  TV_COMPONENT = Parametric::Schema.new do
    field(:slug).type(:string) # .policy(:parameterize).present
    field(:name).type(:string).present
    field(:search_tags).type(:array).default([])
    field(:description).type(:string)
    field(:channels).type(:integer).default(0)
    field(:discount_price).type(:nullable_money).default(Money.zero)
    field(:discount_period).type(:nullable_integer)
    field(:ongoing_price).type(:nullable_money)
    field(:contract_length).type(:nullable_integer)
    field(:upfront_cost).type(:nullable_money)
    field(:commission).type(:nullable_money)
  end
  RECORD = Parametric::Schema.new do
    field(:supplier_name).type(:string).present
    field(:start_date).type(:nullable_date).meta(example: nil, admin_ui: true)
    field(:end_date).type(:nullable_date).meta(example: nil, admin_ui: true)
    field(:countdown_date).type(:nullable_date).meta(example: nil)
    field(:name).type(:string).present.meta(example: 'Visa Platinum', admin_ui: true)
    field(:upfront_cost_description).type(:string).default('')
    field(:tv_channels_count).type(:integer).default(0)
    field(:terms).type(:array).policy(:size, min: 1).default([]).schema TERM
    field(:tv_included).type(:boolean)
    field(:additional_info).type(:string)
    field(:product_type).type(:nullable_string) # computed on ingestion
    field(:annual_price_increase_applies).type(:boolean).default(false)
    field(:annual_price_increase_description).type(:string).default('')
    field(:broadband_components).type(:array).default([]).schema do
      field(:name).type(:string)
      field(:technology).type(:string)
      field(:technology_tags).type(:array).default([])
      field(:is_mobile).type(:boolean).default(false) # computed on ingestion based on technology
      field(:description).type(:string)
      field(:download_speed_measurement).type(:string).default('')
      field(:download_speed).type(:nullable_number).default(0)
      field(:upload_speed_measurement).type(:string)
      field(:upload_speed).type(:nullable_number).default(0)
      field(:download_usage_limit).type(:nullable_integer).default(nil)
      field(:discount_price).type(:nullable_money)
      field(:discount_period).type(:nullable_integer)
      field(:speed_description).type(:string).default('')
      field(:ongoing_price).type(:nullable_money)
      field(:contract_length).type(:nullable_integer)
      field(:upfront_cost).type(:nullable_money)
      field(:commission).type(:nullable_money)
    end
    field(:tv_components).type(:array).default([]).schema TV_COMPONENT
    field(:call_package_types).type(:array).default([]).meta(example: ['Everything']) # computed on ingestion
    field(:phone_components).type(:array).default([]).schema do
      field(:name).type(:string)
      field(:description).type(:string)
      field(:discount_price).type(:nullable_money)
      field(:discount_period).type(:nullable_integer)
      field(:ongoing_price).type(:nullable_money)
      field(:contract_length).type(:nullable_integer)
      field(:upfront_cost).type(:nullable_money)
      field(:commission).type(:nullable_money)
      field(:call_package_type).type(:array).default([])
    end
    field(:payment_methods).type(:array).default([])
    field(:discounts).type(:array).default([]).schema do
      field(:period).type(:integer)
      field(:price).type(:nullable_money)
    end
    field(:ongoing_price).type(:nullable_money).meta(admin_ui: true)
    field(:contract_length).type(:nullable_integer)
    field(:upfront_cost).type(:nullable_money)
    field(:year_1_price).type(:nullable_money).meta(admin_ui: true)
    field(:savings).type(:nullable_money).meta(admin_ui: true)
    field(:commission).type(:nullable_money)
    field(:max_broadband_download_speed).type(:integer).default(0)
  end
end
