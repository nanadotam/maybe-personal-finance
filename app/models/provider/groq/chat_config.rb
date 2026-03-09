class Provider::Groq::ChatConfig
  def initialize(functions: [], function_results: [], instructions: nil)
    @functions = functions
    @function_results = function_results
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
          parameters: fn[:params_schema],
          strict: fn[:strict]
        }
      }
    end
  end

  # Build the messages array for the Chat Completions API
  def build_messages(prompt)
    messages = []

    # System message (instructions)
    messages << { role: "system", content: instructions } if instructions.present?

    # Previous function call results
    function_results.each do |fn_result|
      messages << {
        role: "tool",
        tool_call_id: fn_result[:call_id],
        content: fn_result[:output].to_json
      }
    end

    # Current user message
    messages << { role: "user", content: prompt }

    messages
  end

  private
    attr_reader :functions, :function_results, :instructions
end
