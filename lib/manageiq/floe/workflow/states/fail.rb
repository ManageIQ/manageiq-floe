# frozen_string_literal: true

module ManageIQ
  module Floe
    class Workflow
      module States
        class Fail < ManageIQ::Floe::Workflow::State
          attr_reader :cause, :error

          def initialize(workflow, name, payload)
            super

            @cause = payload["Cause"]
            @error = payload["Error"]
          end

          def end?
            true
          end

          def status
            "errored"
          end

          private def to_dot_attributes
            super.merge(:color => "red")
          end
        end
      end
    end
  end
end
