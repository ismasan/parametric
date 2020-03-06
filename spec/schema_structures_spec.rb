require 'spec_helper'

describe "Schema structures generation" do
  Parametric.policy :policy_with_error do
    register_error ArgumentError

    validate do |*|
      raise ArgumentError
    end
  end

  Parametric.policy :policy_with_silent_error do
    register_silent_error RuntimeError
  end

  let(:schema) do
    Parametric::Schema.new do
      field(:data).type(:object).present.schema do
        field(:id).type(:integer).present.policy(:policy_with_error)
        field(:name).type(:string).meta(label: "very important staff")
        field(:role).type(:string).declared.options(["admin", "user"]).default("user")
        field(:extra).type(:object).required.schema do
          field(:extra).declared.default(false).policy(:policy_with_silent_error)
        end

        subschema_by(:role) { :subschema }
      end
    end
  end
  let(:subschema1) do
    Parametric::Schema.new do
      field(:test1).present
    end
  end

  before do
    schema.subschemes[:subschema] = subschema1
  end

  it "generates nested data for documentation generation" do
    expect(schema.structure).to eq({
      _subschemes: {},
      data: {
        type: :object,
        required: true,
        present: true,
        structure: {
          id: {
            type: :integer,
            required: true,
            present: true,
            policy_with_error: {errors: [ArgumentError]}
          },
          name: {
            type: :string,
            label: "very important staff"
          },
          role: {
            type: :string,
            options: ["admin", "user"],
            default: "user"
          },
          extra: {
            type: :object,
            required: true,
            structure: {
              extra: {default: false},
              _subschemes: {}
            }
          },
          _identifiers: [:role],
          _subschemes: {
            subschema: {
              _errors: [],
              _subschemes: {},
              test1: {required: true, present: true}
            }
          }
        }
      },
      _errors: [ArgumentError]
    })
  end

  it "generates flatten data for documentation generation" do
    sisi = schema.structure
    expect(schema.flatten_structure).to eq({
      "data" => {
        type: :object,
        required: true,
        present: true,
        json_path: "$.data"
      },
      "data.extra" => {
        type: :object,
        required: true,
        json_path: "$.data.extra"
      },
      "data.extra.extra" => {
        default: false,
        json_path: "$.data.extra.extra"
      },
      "data.id" => {
        type: :integer,
        required: true,
        present: true,
        json_path: "$.data.id",
        policy_with_error: {errors: [ArgumentError]}
      },
      "data.name" => {
        type: :string,
        json_path: "$.data.name",
        label: "very important staff"
      },
      "data.role" => {
        type: :string,
        options: ["admin", "user"],
        default: "user",
        json_path: "$.data.role"
      },
      _errors: [ArgumentError],
      _identifiers: ["data.role"],
      _subschemes: {
        subschema: {
          _errors: [],
          _subschemes: {},
          "data.test1"=>{
            required: true,
            present: true,
            json_path: "$.data.test1"
          }
        }
      }
    })
  end
end
