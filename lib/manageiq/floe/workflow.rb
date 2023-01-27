# frozen_string_literal: true

require "json"

module ManageIQ
  module Floe
    class Workflow
      class << self
        def load(path_or_io, context = {})
          payload = path_or_io.respond_to?(:read) ? path_or_io.read : File.read(path_or_io)
          new(payload, context)
        end
      end

      attr_reader :context, :payload, :states, :states_by_name, :current_state, :status

      def initialize(payload, context = {})
        payload = JSON.parse(payload) if payload.kind_of?(String)
        context = JSON.parse(context) if context.kind_of?(String)

        @payload = payload
        @context = context

        @states         = parse_states
        @states_by_name = @states.each_with_object({}) { |state, result| result[state.name] = state }
        start_at        = @payload["StartAt"]

        @context["states"] ||= []
        @context["current_state"] ||= start_at

        current_state_name = @context["current_state"]
        @current_state = @states_by_name[current_state_name]

        @status = current_state_name == start_at ? "pending" : current_state.status
      rescue JSON::ParserError => err
        raise ManageIQ::Floe::InvalidWorkflowError, err.message
      end

      def step
        @status = "running" if @status == "pending"

        tick = Time.now.utc
        next_state, outputs = current_state.run!
        tock = Time.now.utc

        @context["states"] << {"start" => tick, "end" => tock, "time" => tock - tick, "outputs" => outputs}

        @status = current_state.status

        next_state_name = next_state&.name
        @context["current_state"] = next_state_name
        @current_state = next_state_name && @states_by_name[next_state_name]

        self
      end

      def run!
        until end?
          step
        end
        self
      end

      def end?
        current_state.nil?
      end

      def to_dot
        String.new.tap do |s|
          s << "digraph {\n"
          states.each do |state|
            s << state.to_dot << "\n"
          end
          s << "\n"
          states.each do |state|
            Array(state.to_dot_transitions).each do |transition|
              s << transition << "\n"
            end
          end
          s << "}\n"
        end
      end

      def to_svg(path: nil)
        require "open3"
        out, err, _status = Open3.capture3("dot -Tsvg", :stdin_data => to_dot)

        raise "Error from graphviz:\n#{err}" if err && !err.empty?

        File.write(path, out) if path

        out
      end

      private

      def parse_states
        payload["States"].map do |name, state_payload|
          State.build!(self, name, state_payload)
        end
      end
    end
  end
end
