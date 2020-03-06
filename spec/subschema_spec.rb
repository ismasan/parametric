require 'spec_helper'
require "paradocs/dsl"

describe "schemes with subschemes" do
  let(:validation_class) do
    Class.new do
      include Paradocs::DSL

      schema(:request) do
        field(:action).present.options([:update, :delete])
        subschema_by(:action) do |action|
          action == :update ? :update_schema : :generic_schema
        end
      end

      subschema_for(:request, name: :update_schema) do
        field(:event).present
      end

      subschema_for(:request, name: :generic_schema) do
        field(:generic_field).present
      end

      def self.validate(schema_name, data)
        schema(schema_name).resolve(data)
      end
    end
  end

  let(:update_request) {
    {
      action: :update,
      event:  "test"
    }
  }

  it "invokes necessary subschema based on condition" do
    valid_result = validation_class.validate(:request, update_request)
    expect(valid_result.output).to eq(update_request)
    expect(valid_result.errors).to eq({})

    failed_result = validation_class.validate(:request, {action: :update, generic_field: "test"})

    expect(failed_result.errors).to eq({"$.event"=>["is required"]})
    expect(failed_result.output).to eq({action: :update, event: nil})
  end
end
