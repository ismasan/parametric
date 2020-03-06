require "spec_helper"

describe "custom validator" do
  let(:validator) do
    class PresentIf < Parametric::BasePolicy
      def initialize(condition)
        @condition = @condition
      end

      def validate(value, key, payload)
        value.present? && key.present?
      end

      def eligible?(value, key, payload)
        condition.call(value, key, payload)
      end
    end
    PresentIf
  end

  describe "registration" do
    it "doesn't raise error if validator is built properly" do
      expect { Parametric.policy :present_if, validator }.to_not raise_error
      expect(Parametric.registry.policies[:present_if]).to eq(validator)
    end

    it "raises ConfigurationError if validator class doesn't respond to required methods" do
      expect { Parametric.policy :bad_validator, Class.new }.to raise_error(Parametric::ConfigurationError)
        .with_message(/Policy .* should respond to \[:valid\?, :coerce, :eligible\?, :meta_data, :policy_name\]/)
    end

    it "raises ConfigrationError if child validator class overrides #valid? method" do
      expect do
        Parametric.policy(
          :bad_validator,
          Class.new(Parametric::BasePolicy) do
            define_method(:valid?) { true }
          end
        )
      end.to raise_error(Parametric::ConfigurationError)
        .with_message(/Overriding #valid\? in .* is forbidden\. Override #validate instead/)
    end

    context "with enabled explicit_errors" do
      before { allow(Parametric.config).to receive(:explicit_errors) { true } }

      it "raises ConfigurationError if custom validator doesn't implement .errors method" do
        validator = Class.new do
          def valid?; end
          def coerce; end
          def eligible?; end
          def meta_data; end
          def policy_name; end
        end

        expect { Parametric.policy :malformed_validator, validator }.to raise_error(Parametric::ConfigurationError)
          .with_message(/Policy .* should respond to \.errors method/)
      end
    end
  end
end
