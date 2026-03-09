class Provider::Groq::ChatStreamParser
  Error = Class.new(StandardError)

  def initialize(object)
    @object = object
  end

  # The ruby-openai gem yields raw Hash chunks from the SSE stream.
  # For chat completions, a delta chunk looks like:
  #   { "choices" => [{ "delta" => { "content" => "..." } }] }
  # A tool_call delta chunk looks like:
  #   { "choices" => [{ "delta" => { "tool_calls" => [{ "index" => 0, "id" => "...", "function" => { "name" => "...", "arguments" => "..." } }] } }] }
  # A finish chunk has finish_reason set.
  def parsed
    return nil unless object.is_a?(Hash)

    choices = object.dig("choices") || []
    return nil if choices.empty?

    choice = choices.first
    delta  = choice.dig("delta") || {}
    finish = choice.dig("finish_reason")

    if delta["content"].present?
      Chunk.new(type: "output_text", data: delta["content"])
    elsif delta["tool_calls"].present?
      Chunk.new(type: "tool_call_delta", data: delta["tool_calls"])
    elsif finish.present?
      Chunk.new(type: "finish", data: finish)
    end
  end

  private
    attr_reader :object

    Chunk = Provider::LlmConcept::ChatStreamChunk
end
