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

  MONEY_EXP = /(\W{1}|\w{3})?[\d+,.]/

  PARSE_DATE = proc do |result|
    date = ::Date.parse(result.value)
    result.success(date)
  rescue ::Date::Error
    result.halt(error: 'invalid date')
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

  TermHash = Hash[
    name: String.default(''),
    url: String.default(''),
    terms_text: String.default(''),
    start_date?: BlankStringOrDate.optional,
    end_date: BlankStringOrDate.optional
  ]

  TvComponentHash = Hash[
    slug: String,
    name: String.present,
    search_tags: Array[String].default([]),
    description: String.default(''),
    channels: Integer.default(0),
    discount_price: Money.default(::Money.zero)
  ]

  HashSchema = Hash[
    supplier_name: String.present,
    start_date: BlankStringOrDate.optional.meta(admin_ui: true),
    end_date: BlankStringOrDate.optional.meta(admin_ui: true),
    countdown_date: BlankStringOrDate.optional,
    name: String.present,
    upfront_cost_description: String.default(''),
    tv_channels_count: Integer.default(0),
    terms: Array[TermHash].rule(size: (1..)).default([]),
    tv_included: Boolean,
    additional_info: String,
    product_type: String.optional,
    annual_price_increase_applies: Boolean.default(false),
    annual_price_increase_description: String.default(''),
    broadband_components: Array[
      name: String,
      technology: String,
      technology_tags: Array[String].default([]),
      is_mobile: Boolean.default(false),
      description: String,
      download_speed_measurement: String.default(''),
      download_speed: Numeric.default(0),
      upload_speed_measurement: String,
      upload_speed: Numeric.default(0),
      download_usage_limit: Integer.optional,
      discount_price: Money.optional,
      discount_period?: Integer.optional,
      speed_description: String.default(''),
      ongoing_price: Money.optional,
      contract_length: Integer.optional,
      upfront_cost: Money.optional,
      commission: Money.optional
    ],
    tv_components: Array[TvComponentHash].default([]),
    call_package_types: Array[String].default([]).meta(example: ['Everything']),
    phone_components: Array[
      name: String,
      description: String,
      discount_price: Money.optional,
      discount_period: Integer.optional,
      ongoing_price: Money.optional,
      contract_length: Integer.optional,
      upfront_cost: Money.optional,
      commission: Money.optional,
      call_package_type: Array[String].default([])
    ].default([]),
    payment_methods: Array[String].default([]),
    discounts: Array[
      period: Integer,
      price: Money.optional
    ],
    ongoing_price: Money.optional.meta(admin_ui: true),
    contract_length: Integer.optional,
    upfront_cost: Money.optional,
    year_1_price: Money.optional.meta(admin_ui: true),
    savings: Money.optional.meta(admin_ui: true),
    commission: Money.optional,
    max_broadband_download_speed: Integer.default(0)
  ]
end
