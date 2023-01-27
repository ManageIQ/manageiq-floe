# frozen_string_literal: true

module ManageIQ
  module Floe
    class Workflow
      class State
        include Logging

        class << self
          def build!(workflow, name, payload)
            state_type = payload["Type"]

            begin
              klass = ManageIQ::Floe::Workflow::States.const_get(state_type)
            rescue NameError
              raise ManageIQ::Floe::InvalidWorkflowError, "Invalid state type: [#{state_type}]"
            end

            klass.new(workflow, name, payload)
          end
        end

        attr_reader :workflow, :comment, :name, :type, :payload

        def initialize(workflow, name, payload)
          @workflow = workflow
          @name     = name
          @payload  = payload
          @end      = !!payload["End"]
          @type     = payload["Type"]
          @comment  = payload["Comment"]
        end

        def end?
          @end
        end

        def context
          workflow.context["global"]
        end

        def status
          end? ? "success" : "running"
        end

        def run!(input)
          logger.info("Running state: [#{name}] with input [#{input}]")

          input = input_path.value(context, input)

          output, next_state = block_given? ? yield(input) : input
          next_state ||= workflow.states_by_name[payload["Next"]] unless end?

          output ||= input
          output   = output_path&.value(context, output)

          logger.info("Running state: [#{name}] with input [#{input}]...Complete - next state: [#{next_state&.name}] output: [#{output}]")

          [next_state, output]
        end

        def to_dot
          String.new.tap do |s|
            s << "  #{name}"

            attributes = to_dot_attributes
            s << " [ #{attributes.to_a.map { |kv| kv.join("=") }.join(" ")} ]" unless attributes.empty?
          end
        end

        private def to_dot_attributes
          end? ? {:style => "bold"} : {}
        end

        def to_dot_transitions
          next_state_name = payload["Next"] unless end?
          Array(next_state_name && "  #{name} -> #{next_state_name}")
        end
      end
    end
  end
end
