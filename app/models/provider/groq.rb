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

      raw_response = client.chat(parameters: {
        model: model,
        messages: messages,
        tools: tools,
        tool_choice: tools.present? ? "auto" : nil
      }.compact)

      if raw_response.is_a?(Hash) && raw_response["error"].present?
        error_message = raw_response["error"]["message"] || raw_response["error"].to_s
        failed_gen = raw_response.dig("error", "failed_generation")
        Rails.logger.error("[Groq] API error: #{error_message}")
        Rails.logger.error("[Groq] Failed generation: #{failed_gen}") if failed_gen.present?
        raise Error, friendly_error_message(error_message)
      end

      parsed = ChatParser.new(raw_response).parsed

      Rails.logger.info("[Groq] Response: text_length=#{parsed.messages.first&.output_text&.length || 0}, tool_calls=#{parsed.function_requests.size}#{parsed.function_requests.any? ? " (#{parsed.function_requests.map(&:function_name).join(', ')})" : ''}")

      # Emit events through the streamer so the Responder can update the UI
      if streamer.present?
        output_text = parsed.messages.first&.output_text
        if output_text.present?
          streamer.call(ChatStreamChunk.new(type: "output_text", data: output_text))
        end
        streamer.call(ChatStreamChunk.new(type: "response", data: parsed))
      end

      parsed
    end
  end

  private
    attr_reader :client

    ChatResponse    = Provider::LlmConcept::ChatResponse
    ChatStreamChunk = Provider::LlmConcept::ChatStreamChunk

    def friendly_error_message(raw_message)
      if raw_message.match?(/rate limit/i)
        wait_match = raw_message.match(/try again in (\d+m[\d.]+s|\d+[\d.]*s)/i)
        wait_time = wait_match ? wait_match[1] : "a few minutes"
        "Rate limit reached — the AI needs to cool down. Try again in #{wait_time}."
      elsif raw_message.match?(/too many requests/i)
        "Too many requests — please wait a moment before trying again."
      elsif raw_message.match?(/invalid api key|authentication/i)
        "AI provider authentication failed. Please check your Groq API key in settings."
      elsif raw_message.match?(/model.*not found|does not exist/i)
        "The selected AI model is not available. Please try a different model."
      elsif raw_message.match?(/failed to call a function|failed_generation/i)
        "The AI had trouble processing your request. Please try rephrasing your message."
      else
        raw_message
      end
    end

    def default_error_transformer(error)
      message = if error.is_a?(Faraday::Error) && error.response
        body = error.response[:body]
        raw = body.is_a?(Hash) ? (body.dig("error", "message") || body.to_s) : body.to_s
        friendly_error_message(raw)
      else
        friendly_error_message(error.message)
      end

      Error.new(message)
    end
end
