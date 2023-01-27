# frozen_string_literal: true

module ManageIQ
  module Floe
    class Workflow
      module States
        class Choice < ManageIQ::Floe::Workflow::State
          attr_reader :choices, :default

          def initialize(workflow, name, payload)
            super

            @choices = payload["Choices"]
            @default = payload["Default"]
          end

          def run!
            logger.info("Running state: [#{name}]")

            next_state_name = choices.map { |choice| ChoiceRule.build(choice, workflow.context["global"]) }.detect(&:true?)&.next || default

            next_state = workflow.states_by_name[next_state_name]
            results = {}

            [next_state, results]
          end

          private def to_dot_attributes
            super.merge(:shape => "diamond")
          end

          def to_dot_transitions
            [].tap do |a|
              choices.each do |choice|
                choice_label =
                  if choice["NumericEquals"]
                    "#{choice["Variable"]} == #{choice["NumericEquals"]}"
                  else
                    "Unknown" # TODO
                  end

                a << "  #{name} -> #{choice["Next"]} [ label=#{choice_label.inspect} ]"
              end

              a << "  #{name} -> #{default} [ label=\"Default\" ]" if default
            end
          end
        end
      end
    end
  end
end
