# Maybe API Documentation

Base URL: `http://your-maybe-instance/api/v1`

## Authentication

All API endpoints require authentication via one of two methods:

### API Key (recommended for personal use)
```bash
curl -H "X-Api-Key: YOUR_API_KEY" http://localhost:3000/api/v1/accounts
```

Generate an API key from **Settings > API Key** in the Maybe app.

### OAuth 2.0 (for third-party apps)
```bash
curl -H "Authorization: Bearer ACCESS_TOKEN" http://localhost:3000/api/v1/accounts
```

OAuth uses Doorkeeper with PKCE. Scopes: `read` (default), `read_write`.

## Rate Limits

Rate limits are applied per API key. Response headers include:
- `X-RateLimit-Limit` - Max requests allowed
- `X-RateLimit-Remaining` - Requests remaining
- `X-RateLimit-Reset` - Seconds until limit resets

## Error Responses

All errors follow this format:
```json
{
  "error": "error_code",
  "message": "Human readable message",
  "errors": ["Specific validation errors"]
}
```

| Status | Code | Meaning |
|--------|------|---------|
| 400 | `bad_request` | Malformed request |
| 401 | `unauthorized` | Missing or invalid auth |
| 404 | `not_found` | Resource not found |
| 422 | `validation_failed` | Invalid data |
| 429 | `rate_limit_exceeded` | Too many requests |

---

## Endpoints

### Accounts

#### List Accounts
```
GET /api/v1/accounts
```
**Scope:** `read`

**Query params:** `page`, `per_page` (default 25, max 100)

**Response:**
```json
{
  "accounts": [
    {
      "id": "uuid",
      "name": "Savings",
      "balance": "11925.53",
      "currency": "GHS",
      "classification": "asset",
      "account_type": "depository"
    }
  ],
  "pagination": {
    "page": 1,
    "per_page": 25,
    "total_count": 4,
    "total_pages": 1
  }
}
```

---

### Transactions

#### List Transactions
```
GET /api/v1/transactions
```
**Scope:** `read`

**Query params:**

| Param | Type | Description |
|-------|------|-------------|
| `page` | integer | Page number (default 1) |
| `per_page` | integer | Results per page (default 25, max 100) |
| `account_id` | uuid | Filter by account |
| `category_id` | uuid | Filter by category |
| `merchant_id` | uuid | Filter by merchant |
| `start_date` | YYYY-MM-DD | Filter from date |
| `end_date` | YYYY-MM-DD | Filter to date |
| `min_amount` | decimal | Minimum amount |
| `max_amount` | decimal | Maximum amount |
| `type` | string | `income` or `expense` |
| `search` | string | Search name, notes, merchant |
| `tag_ids[]` | uuid[] | Filter by tags |

**Response:**
```json
{
  "transactions": [
    {
      "id": "uuid",
      "date": "2026-03-09",
      "amount": "24.00",
      "currency": "GHS",
      "name": "Food",
      "notes": null,
      "classification": "expense",
      "account": {
        "id": "uuid",
        "name": "Savings",
        "account_type": "depository"
      },
      "category": {
        "id": "uuid",
        "name": "Food & Drink",
        "classification": "expense",
        "color": "#...",
        "icon": "..."
      },
      "merchant": null,
      "tags": [],
      "transfer": null,
      "created_at": "2026-03-09T12:00:00Z",
      "updated_at": "2026-03-09T12:00:00Z"
    }
  ],
  "pagination": { ... }
}
```

#### Get Transaction
```
GET /api/v1/transactions/:id
```
**Scope:** `read`

**Response:** Single transaction object (same shape as above).

#### Create Transaction
```
POST /api/v1/transactions
```
**Scope:** `read_write`

**Request body:**
```json
{
  "transaction": {
    "account_id": "uuid (required)",
    "name": "Food",
    "amount": "24.00",
    "nature": "expense",
    "date": "2026-03-09",
    "currency": "GHS",
    "category_id": "uuid",
    "merchant_id": "uuid",
    "notes": "Lunch at restaurant",
    "tag_ids": ["uuid"]
  }
}
```

| Field | Required | Description |
|-------|----------|-------------|
| `account_id` | yes | Account to add transaction to |
| `amount` | yes | Positive number |
| `nature` | yes | `income`, `expense`, `inflow`, or `outflow` |
| `name` | no | Description (or use `description`) |
| `date` | no | YYYY-MM-DD (defaults to today) |
| `currency` | no | ISO currency code (defaults to family currency) |
| `category_id` | no | Category UUID |
| `merchant_id` | no | Merchant UUID |
| `notes` | no | Free text notes |
| `tag_ids` | no | Array of tag UUIDs |

**Amount signing:** `income`/`inflow` = stored as negative. `expense`/`outflow` = stored as positive.

**Response:** `201 Created` with the transaction object.

#### Update Transaction
```
PATCH /api/v1/transactions/:id
```
**Scope:** `read_write`

**Request body:** Same fields as create (all optional).

**Response:** Updated transaction object.

#### Delete Transaction
```
DELETE /api/v1/transactions/:id
```
**Scope:** `read_write`

**Response:** `200 OK`
```json
{
  "message": "Transaction deleted successfully"
}
```

---

### Chats (AI Assistant)

See [chats.md](chats.md) for full AI chat API documentation.

#### Quick Start
```bash
# Create a chat with initial message
curl -X POST http://localhost:3000/api/v1/chats \
  -H "X-Api-Key: YOUR_KEY" \
  -H "Content-Type: application/json" \
  -d '{"message": "What is my net worth?", "model": "llama-3.3-70b-versatile"}'

# Poll for response
curl http://localhost:3000/api/v1/chats/CHAT_ID \
  -H "X-Api-Key: YOUR_KEY"
```

The AI assistant can:
- Query accounts, balances, net worth
- Search and filter transactions
- View income/expense breakdowns
- Create new transactions

AI responses are generated asynchronously. Poll the chat endpoint to check for new assistant messages.

---

### Usage

#### Get API Usage
```
GET /api/v1/usage
```
**Scope:** `read`

Shows current rate limit status for your API key.

---

## Examples

### cURL
```bash
# List accounts
curl -H "X-Api-Key: YOUR_KEY" http://localhost:3000/api/v1/accounts

# Create an expense
curl -X POST http://localhost:3000/api/v1/transactions \
  -H "X-Api-Key: YOUR_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "transaction": {
      "account_id": "YOUR_ACCOUNT_ID",
      "name": "Groceries",
      "amount": "50.00",
      "nature": "expense",
      "date": "2026-03-09",
      "category_id": "YOUR_CATEGORY_ID"
    }
  }'

# Search transactions
curl "http://localhost:3000/api/v1/transactions?search=food&type=expense&start_date=2026-01-01" \
  -H "X-Api-Key: YOUR_KEY"
```

### Python
```python
import requests

BASE = "http://localhost:3000/api/v1"
HEADERS = {"X-Api-Key": "YOUR_KEY"}

# List accounts
accounts = requests.get(f"{BASE}/accounts", headers=HEADERS).json()

# Create transaction
requests.post(f"{BASE}/transactions", headers=HEADERS, json={
    "transaction": {
        "account_id": accounts["accounts"][0]["id"],
        "name": "Coffee",
        "amount": "5.00",
        "nature": "expense"
    }
})
```

### JavaScript
```javascript
const BASE = "http://localhost:3000/api/v1";
const headers = { "X-Api-Key": "YOUR_KEY", "Content-Type": "application/json" };

// List accounts
const accounts = await fetch(`${BASE}/accounts`, { headers }).then(r => r.json());

// Create transaction
await fetch(`${BASE}/transactions`, {
  method: "POST",
  headers,
  body: JSON.stringify({
    transaction: {
      account_id: accounts.accounts[0].id,
      name: "Coffee",
      amount: "5.00",
      nature: "expense"
    }
  })
});
```
