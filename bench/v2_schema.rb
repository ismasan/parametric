require 'parametric/v2'
require 'date'
require 'money'
require 'monetize'
require 'debug'

class Money
  def ==(other)
    case other
    when Money
      cents == other.cents
    when Numeric
      cents == other.to_i
    else
      false
    end
  end
end

module V2Schemas
  include Parametric::V2::Types

  MONEY_EXP = /(\W{1}|\w{3})?[\d+\,\.]/

  PARSE_DATE = proc do |result|
    begin
      date = ::Date.parse(result.value)
      result.success(date)
    rescue ::Date::Error
      result.halt(error: 'invalid date')
    end
  end

  PARSE_MONEY = proc do |result|
    value = Monetize.parse!(result.value.to_s.gsub(',', ''))
    result.success(value)
  end

  Date = Any.is_a(::Date) \
    | (String.match(MONEY_EXP) >> PARSE_DATE)

  BlankStringOrDate = Forms::Nil | Date

  Money = Any.is_a(::Money) \
    | (String.present >> PARSE_MONEY) \
    | (Numeric >> PARSE_MONEY)

  Term = Parametric::V2::Schema.new do |sc|
    sc.field(:name).type(String).default('')
    sc.field(:url).type(String).default('')
    sc.field(:terms_text).type(String).default('')
    sc.field?(:start_date).type(BlankStringOrDate).optional
    sc.field?(:end_date).type(BlankStringOrDate).optional
  end

  TvComponent = Parametric::V2::Schema.new do |sc|
    sc.field(:slug).type(String)
    sc.field(:name).type(String).present
    sc.field(:search_tags).array(String).default([])
    sc.field(:description).type(String).default('')
    sc.field(:channels).type(Integer).default(0)
    sc.field(:discount_price).type(Money).default(::Money.zero)
  end

  Record = Parametric::V2::Schema.new do |sc|
    sc.field(:supplier_name).type(String).present
    sc.field(:start_date).type(BlankStringOrDate).optional.meta(admin_ui: true)
    sc.field(:end_date).type(BlankStringOrDate).optional.meta(admin_ui: true)
    sc.field(:countdown_date).type(BlankStringOrDate).optional
    sc.field(:name).type(String).present
    sc.field(:upfront_cost_description).type(String).default('')
    sc.field(:tv_channels_count).type(Integer).default(0)
    sc.field(:terms).array(Term).rule(size: (1..)).default([])
    sc.field(:tv_included).type(Boolean)
    sc.field(:additional_info).type(String)
    sc.field(:product_type).type(String).optional
    sc.field(:annual_price_increase_applies).type(Boolean).default(false)
    sc.field(:annual_price_increase_description).type(String).default('')
    sc.field(:broadband_components).default([]).array do |f|
      f.field(:name).type(String)
      f.field(:technology).type(String)
      f.field(:technology_tags).array(String).default([])
      f.field(:is_mobile).type(Boolean).default(false)
      f.field(:description).type(String)
      f.field(:download_speed_measurement).type(String).default('')
      f.field(:download_speed).type(Numeric).default(0)
      f.field(:upload_speed_measurement).type(String)
      f.field(:upload_speed).type(Numeric).default(0)
      f.field(:download_usage_limit).type(Integer).optional
      f.field(:discount_price).type(Money).optional
      f.field(:discount_period).type(Integer).optional
      f.field(:speed_description).type(String).default('')
      f.field(:ongoing_price).type(Money).optional
      f.field(:contract_length).type(Integer).optional
      f.field(:upfront_cost).type(Money).optional
      f.field(:commission).type(Money).optional
    end
    sc.field(:tv_components).array(TvComponent).default([])
    sc.field(:call_package_types).array(String).default([]).meta(example: ['Everything'])
    sc.field(:phone_components).default([]).array do |f|
      f.field(:name).type(String)
      f.field(:description).type(String)
      f.field(:discount_price).type(Money).optional
      f.field?(:discount_period).type(Integer).optional
      f.field(:ongoing_price).type(Money).optional
      f.field(:contract_length).type(Integer).optional
      f.field(:upfront_cost).type(Money).optional
      f.field(:commission).type(Money).optional
      f.field(:call_package_type).array(String).default([])
    end
    sc.field(:payment_methods).array(String).default([])
    sc.field(:discounts).default([]).array do |f|
      f.field(:period).type(Integer)
      f.field(:price).type(Money).optional
    end
    sc.field(:ongoing_price).type(Money).optional.meta(admin_ui: true)
    sc.field(:contract_length).type(Integer).optional
    sc.field(:upfront_cost).type(Money).optional
    sc.field(:year_1_price).type(Money).optional.meta(admin_ui: true)
    sc.field(:savings).type(Money).optional.meta(admin_ui: true)
    sc.field(:commission).type(Money).optional
    sc.field(:max_broadband_download_speed).type(Integer).default(0)
  end
end
