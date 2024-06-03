require 'benchmark/ips'
require 'money'
require 'monetize'
require 'parametric'
require 'parametric/v2'
Money.rounding_mode = BigDecimal::ROUND_HALF_EVEN
Money.default_currency = 'GBP'
require_relative './v1_schema'
require_relative './v2_schema'

# module Types
#   include Parametric::V2::Types
# end

# LegacySchema = Parametric::Schema.new do |sc, _|
#   sc.field(:name).type(:string).default('Mr')
#   sc.field(:friend).schema do |s|
#     s.field(:name).type(:string)
#     s.field(:age).type(:integer)
#   end
#   sc.field(:companies).type(:array).schema do |s|
#     s.field(:name).type(:string)
#   end
# end

# V2Schema = Parametric::V2::Schema.new do |sc|
#   sc.field(:name).type(Types::String).default('Mr')
#   sc.field(:friend).schema do |s|
#     s.field(:name).type(Types::String)
#     s.field(:age).type(Types::Lax::Integer)
#   end
#   sc.field(:companies).array do |f|
#     f.field(:name).type(Types::String)
#   end
# end

# V2Hash = Types::Hash[
#   name: Types::String,
#   friend: Types::Hash[
#     name: Types::String,
#     age: Types::Lax::Integer
#   ],
#   companies: Types::Array[
#     Types::Hash[name: Types::String]
#   ]
# ]

data = {
  supplier_name: 'Vodafone',
  start_date: '2020-01-01',
  end_date: '2021-01-11',
  countdown_date: '2021-01-11',
  name: 'Vodafone TV',
  upfront_cost_description: 'Upfront cost description',
  tv_channels_count: 100,
  terms: [
    { name: 'Foo', url: 'http://foo.com', terms_text: 'Foo terms', start_date: '2020-01-01', end_date: '2021-01-01' },
    { name: 'Foo2', url: 'http://foo2.com', terms_text: 'Foo terms', start_date: '2020-01-01', end_date: '2021-01-01' },
  ],
  tv_included: true,
  additional_info: 'Additional info',
  product_type: 'TV',
  annual_price_increase_applies: true,
  annual_price_increase_description: 'Annual price increase description',
  broadband_components: [
    {
      name: 'Broadband 1',
      technology: 'FTTP',
      technology_tags: ['FTTP'],
      is_mobile: false,
      description: 'Broadband 1 description',
      download_speed_measurement: 'Mbps',
      download_speed: 100,
      upload_speed_measurement: 'Mbps',
      upload_speed: 100,
      download_usage_limit: 1000,
      discount_price: 100,
      discount_period: 12,
      speed_description: 'Speed description',
      ongoing_price: 100,
      contract_length: 12,
      upfront_cost: 100,
      commission: 100
    }
  ],
  tv_components: [
    {
      slug: 'vodafone-tv',
      name: 'Vodafone TV',
      search_tags: ['Vodafone', 'TV'],
      description: 'Vodafone TV description',
      channels: 100,
      discount_price: 100
    }
  ],
  call_package_types: ['Everything'],
  phone_components: [
    {
      name: 'Phone 1',
      description: 'Phone 1 description',
      discount_price: 100,
      disount_period: 12,
      ongoing_price: 100,
      contract_length: 12,
      upfront_cost: 100,
      commission: 100,
      call_package_types: ['Everything']
    }
  ],
  payment_methods: ['Credit Card', 'Paypal'],
  discounts: [
    { period: 12, price: 100 }
  ],
  ongoing_price: 100,
  contract_length: 12,
  upfront_cost: 100,
  year_1_price: 100,
  savings: 100,
  commission: 100,
  max_broadband_download_speed: 100
}

# p V1Schemas::RECORD.resolve(data).errors
# p V2Schemas::Record.resolve(data)
# result = Parametric::V2::Result.wrap(data)

# p result
# p V2Schema.call(result)
Benchmark.ips do |x|
  x.report('Parametric::Schema') {
    V1Schemas::RECORD.resolve(data)
  }
  x.report('Parametric::V2::Schema') {
    V2Schemas::Record.resolve(data)
  }
  # x.report('Parametric::V2::Hash') {
  #   V2Hash.resolve(data)
  # }
  x.compare!
end
