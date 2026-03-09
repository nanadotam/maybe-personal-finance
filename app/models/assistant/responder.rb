class Assistant::Responder
  def initialize(message:, instructions:, function_tool_caller:, llm:)
    @message = message
    @instructions = instructions
    @function_tool_caller = function_tool_caller
    @llm = llm
  end

  def on(event_name, &block)
    listeners[event_name.to_sym] << block
  end

  def respond(previous_response_id: nil)
    # For the first response
    streamer = proc do |chunk|
      case chunk.type
      when "output_text"
        emit(:output_text, chunk.data)
      when "response"
        response = chunk.data

        if response.function_requests.any?
          handle_follow_up_response(response)
        else
          emit(:response, { id: response.id })
        end
      end
    end

    get_llm_response(streamer: streamer, previous_response_id: previous_response_id)
  end

  private
    attr_reader :message, :instructions, :function_tool_caller, :llm

    def handle_follow_up_response(response)
      streamer = proc do |chunk|
        case chunk.type
        when "output_text"
          emit(:output_text, chunk.data)
        when "response"
          # We do not currently support function executions for a follow-up response (avoid recursive LLM calls that could lead to high spend)
          emit(:response, { id: chunk.data.id })
        end
      end

      function_tool_calls = function_tool_caller.fulfill_requests(response.function_requests)

      emit(:response, {
        id: response.id,
        function_tool_calls: function_tool_calls
      })

      # Build function_requests info for the follow-up (needed for proper message ordering)
      fn_requests_for_context = response.function_requests.map do |fr|
        { call_id: fr.call_id, function_name: fr.function_name, function_args: fr.function_args }
      end

      # Get follow-up response with tool call results.
      # Don't send tools so the model is forced to respond with text
      # (prevents infinite tool-call loops that waste tokens).
      get_llm_response(
        streamer: streamer,
        function_results: function_tool_calls.map(&:to_result),
        function_requests: fn_requests_for_context,
        previous_response_id: response.id,
        include_tools: false
      )
    end

    def get_llm_response(streamer:, function_results: [], function_requests: [], previous_response_id: nil, include_tools: true)
      response = llm.chat_response(
        message.content,
        model: message.ai_model,
        instructions: instructions,
        functions: include_tools ? function_tool_caller.function_definitions : [],
        function_results: function_results,
        function_requests: function_requests,
        streamer: streamer,
        previous_response_id: previous_response_id
      )

      unless response.success?
        raise response.error
      end

      response.data
    end

    def emit(event_name, payload = nil)
      listeners[event_name.to_sym].each { |block| block.call(payload) }
    end

    def listeners
      @listeners ||= Hash.new { |h, k| h[k] = [] }
    end
end
