class Provider::Groq::ChatConfig
  def initialize(functions: [], function_results: [], function_requests: [], instructions: nil)
    @functions = functions
    @function_results = function_results
    @function_requests = function_requests
    @instructions = instructions
  end

  def tools
    return [] if functions.empty?

    functions.map do |fn|
      {
        type: "function",
        function: {
          name: fn[:name],
          description: fn[:description],
          parameters: fn[:params_schema]
          # Note: Groq does not support OpenAI's 'strict' mode parameter
        }
      }
    end
  end

  # Build the messages array for the Chat Completions API
  #
  # When function_results are present (follow-up after tool calls), the order must be:
  #   1. system message
  #   2. user message
  #   3. assistant message with tool_calls (the LLM's original request to call functions)
  #   4. tool result messages (one per function call)
  def build_messages(prompt)
    messages = []

    # System message (instructions)
    messages << { role: "system", content: instructions } if instructions.present?

    # Current user message
    messages << { role: "user", content: prompt }

    # If we have function results, we need the assistant's tool_calls message first
    if function_results.any? && function_requests.any?
      # Reconstruct the assistant message that requested the tool calls
      messages << {
        role: "assistant",
        content: nil,
        tool_calls: function_requests.map do |fr|
          {
            id: fr[:call_id],
            type: "function",
            function: {
              name: fr[:function_name],
              arguments: fr[:function_args]
            }
          }
        end
      }

      # Then add tool result messages
      function_results.each do |fn_result|
        messages << {
          role: "tool",
          tool_call_id: fn_result[:call_id],
          content: fn_result[:output].to_json
        }
      end
    end

    messages
  end

  private
    attr_reader :functions, :function_results, :function_requests, :instructions
end
