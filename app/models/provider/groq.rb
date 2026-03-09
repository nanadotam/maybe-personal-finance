class Provider::Groq < Provider
  include LlmConcept

  # Subclass so errors caught in this provider are raised as Provider::Groq::Error
  Error = Class.new(Provider::Error)

  # Models available on Groq's fast inference API (as of March 2026)
  MODELS = %w[llama-3.1-8b-instant llama-3.3-70b-versatile]

  def initialize(access_token)
    @client = ::OpenAI::Client.new(
      access_token: access_token,
      uri_base: "https://api.groq.com/openai/v1"
    )
  end

  def supports_model?(model)
    true
  end

  def auto_categorize(transactions: [], user_categories: [])
    with_provider_response do
      raise Error, "Too many transactions to auto-categorize. Max is 25 per request." if transactions.size > 25

      AutoCategorizer.new(
        client,
        transactions: transactions,
        user_categories: user_categories
      ).auto_categorize
    end
  end

  def auto_detect_merchants(transactions: [], user_merchants: [])
    with_provider_response do
      raise Error, "Too many transactions to auto-detect merchants. Max is 25 per request." if transactions.size > 25

      AutoMerchantDetector.new(
        client,
        transactions: transactions,
        user_merchants: user_merchants
      ).auto_detect_merchants
    end
  end

  def chat_response(prompt, model:, instructions: nil, functions: [], function_results: [], function_requests: [], streamer: nil, previous_response_id: nil)
    with_provider_response do
      chat_config = ChatConfig.new(
        functions: functions,
        function_results: function_results,
        function_requests: function_requests,
        instructions: instructions
      )

      messages = chat_config.build_messages(prompt)
      tools = chat_config.tools.presence

      Rails.logger.info("[Groq] Sending chat request: model=#{model}, messages=#{messages.size}, tools=#{tools&.size || 0}, function_results=#{function_results.size}")

      if streamer.present?
        # Streaming via Chat Completions SSE
        full_text = ""
        tool_calls_by_index = {}

        stream_proc = proc do |chunk, _bytesize|
          parsed_chunk = ChatStreamParser.new(chunk).parsed
          next unless parsed_chunk

          case parsed_chunk.type
          when "output_text"
            streamer.call(parsed_chunk)
            full_text << parsed_chunk.data
          when "tool_call_delta"
            # Accumulate tool call deltas (arguments arrive in chunks)
            parsed_chunk.data.each do |tc_delta|
              idx = tc_delta["index"]
              tool_calls_by_index[idx] ||= { "id" => nil, "function" => { "name" => "", "arguments" => "" } }
              tool_calls_by_index[idx]["id"] = tc_delta["id"] if tc_delta["id"].present?
              tool_calls_by_index[idx]["function"]["name"] = tc_delta.dig("function", "name") if tc_delta.dig("function", "name").present?
              tool_calls_by_index[idx]["function"]["arguments"] << tc_delta.dig("function", "arguments").to_s
            end
          end
        end

        raw = client.chat(parameters: {
          model: model,
          messages: messages,
          tools: tools,
          stream: stream_proc
        }.compact)

        # Check if the API returned an error (stream_proc never called)
        if raw.is_a?(Hash) && raw["error"].present?
          raise Error, "Groq API error: #{raw['error']['message'] || raw['error']}"
        end

        # Log raw response if stream produced nothing (helps debug silent failures)
        if full_text.empty? && tool_calls_by_index.empty?
          Rails.logger.warn("[Groq] Stream produced no output. Raw response: #{raw.inspect.truncate(500)}")
        end

        # Build function requests from accumulated tool call deltas
        fn_requests = tool_calls_by_index.values.map do |tc|
          ChatFunctionRequest.new(
            id: tc["id"],
            call_id: tc["id"],
            function_name: tc.dig("function", "name"),
            function_args: tc.dig("function", "arguments")
          )
        end

        Rails.logger.info("[Groq] Stream complete: text_length=#{full_text.length}, tool_calls=#{fn_requests.size}#{fn_requests.any? ? " (#{fn_requests.map(&:function_name).join(', ')})" : ''}")

        # Build a synthetic final ChatResponse and emit it so the Responder can finalize
        final_response = ChatResponse.new(
          id: nil,
          model: model,
          messages: [ ChatMessage.new(id: nil, output_text: full_text) ],
          function_requests: fn_requests
        )
        streamer.call(ChatStreamChunk.new(type: "response", data: final_response))
        final_response
      else
        raw_response = client.chat(parameters: {
          model: model,
          messages: chat_config.build_messages(prompt),
          tools: chat_config.tools.presence
        }.compact)

        ChatParser.new(raw_response).parsed
      end
    end
  end

  private
    attr_reader :client

    ChatResponse        = Provider::LlmConcept::ChatResponse
    ChatMessage         = Provider::LlmConcept::ChatMessage
    ChatStreamChunk     = Provider::LlmConcept::ChatStreamChunk
    ChatFunctionRequest = Provider::LlmConcept::ChatFunctionRequest
end
