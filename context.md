# Project Context: Maybe Personal Finance - Groq & Market Data Integration

## Objective
The primary goal was to integrate the **Groq API** as the primary LLM provider for AI chatbot and automation features (auto-categorization, merchant detection) while restoring functional **Market Data** fetching using free community APIs (**ExchangeRate-API** and **Financial Modeling Prep**).

## 🛠 AI Integration (Groq)

### 1. Provider Rewrite
Groq does not support the OpenAI-proprietary "Responses API". The entire provider layer was rewritten to use the standard **Chat Completions API** (`/v1/chat/completions`).
- **Files Created/Modified**:
  - `app/models/provider/groq.rb`: Core provider logic.
  - `app/models/provider/groq/chat_config.rb`: Builds system/user/tool messages.
  - `app/models/provider/groq/chat_parser.rb`: Parses standard chat responses.
  - `app/models/provider/groq/chat_stream_parser.rb`: Handles SSE delta chunks.
  - `app/models/provider/groq/auto_categorizer.rb`: Handles transaction categorization using JSON mode.
  - `app/models/provider/groq/auto_merchant_detector.rb`: Handles merchant detection using JSON mode.

### 2. Model Configuration
Old model IDs were decommissioned by Groq. The system now uses:
- **Default Chat**: `llama-3.1-8b-instant` (Fastest inference)
- **Background Tasks**: `llama-3.3-70b-versatile` (Most capable for logic)

### 3. Compatibility Fixes
- **JSON Schema**: Fixed validation errors by omitting empty `properties` and `required` fields in tool definitions.
- **Param Stripping**: Removed the unsupported `strict: true` parameter from tool definitions.
- **Streaming**: Fixed a bug where the streaming loop never emitted the final `response` chunk, causing the UI to hang.

## 📊 Market Data (Free Providers)

### 1. Registry Updates
The `Provider::Registry` was updated to prioritize free providers over the paid `synth` provider.
- **Exchange Rates**: Uses `exchangerate_api`.
- **Securities/Prices**: Uses `financial_modeling_prep`.

### 2. UI/Warning Fixes
- **Missing Data Alert**: Updated `Family#missing_data_provider?` to check for *any* configured market provider. Previously, it only checked for the `synth` API, causing a permanent warning even if other keys were set.
- **Settings UI**: Updated the Hosting settings page to handle and display the new API keys.

## 🔑 Environment Variables (`.env.local`)
- `GROQ_API_KEY`: Groq authentication token.
- `EXCHANGERATE_API_KEY`: For historical currency conversion.
- `FMP_API_KEY`: For historical security price fetching.

## 🚀 Technical Status
- **Ruby**: 3.4.4
- **Rails**: 7.2.2.1
- **Server**: Puma (running on port 3000)
- **Status**: AI Chatbot, Auto-Categorization, and Market Data fetching are verified as working end-to-end.
