class Provider::Groq::ChatParser
  Error = Class.new(StandardError)

  def initialize(object)
    @object = object
  end

  def parsed
    ChatResponse.new(
      id: response_id,
      model: response_model,
      messages: messages,
      function_requests: function_requests
    )
  end

  private
    attr_reader :object

    ChatResponse           = Provider::LlmConcept::ChatResponse
    ChatMessage            = Provider::LlmConcept::ChatMessage
    ChatFunctionRequest    = Provider::LlmConcept::ChatFunctionRequest

    def response_id
      object.dig("id")
    end

    def response_model
      object.dig("model")
    end

    def choices
      object.dig("choices") || []
    end

    def messages
      choices.filter_map do |choice|
        message = choice.dig("message")
        next unless message
        next if message.dig("tool_calls").present?

        ChatMessage.new(
          id: nil,
          output_text: message.dig("content").to_s
        )
      end
    end

    def function_requests
      choices.flat_map do |choice|
        tool_calls = choice.dig("message", "tool_calls") || []

        tool_calls.map do |tc|
          ChatFunctionRequest.new(
            id: tc.dig("id"),
            call_id: tc.dig("id"),
            function_name: tc.dig("function", "name"),
            function_args: tc.dig("function", "arguments")
          )
        end
      end
    end
end
