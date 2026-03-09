# Siri Shortcuts for Maybe Finance

Your Maybe instance at `http://35.227.53.189:3000` exposes a REST API. Here's how to build Siri Shortcuts to log expenses, check balances, and more — all with your voice or a home screen tap.

---

## Your API Details

| Field | Value |
|-------|-------|
| **Base URL** | `http://35.227.53.189:3000/api/v1` |
| **API Key** | `06f6759f81817d90e1aad255bde3aaf2230ababdfc50679c63895a096deb2fa0` |
| **Auth Header** | `X-Api-Key` |

---

## API Reference (Quick)

### GET /accounts
List all accounts (checking, savings, credit cards, etc.)

```
curl -H "X-Api-Key: YOUR_KEY" http://35.227.53.189:3000/api/v1/accounts
```

Response:
```json
{
  "accounts": [
    {
      "id": 123,
      "name": "Checking Account",
      "balance": "$1,234.56",
      "currency": "USD",
      "classification": "asset",
      "account_type": "depository"
    }
  ],
  "pagination": { "page": 1, "per_page": 25, "total_count": 5, "total_pages": 1 }
}
```

### POST /transactions
Create a new transaction (expense or income).

```
curl -X POST \
  -H "X-Api-Key: YOUR_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "transaction": {
      "account_id": 123,
      "name": "Coffee",
      "amount": 5.50,
      "nature": "expense",
      "date": "2026-03-09"
    }
  }' \
  http://35.227.53.189:3000/api/v1/transactions
```

**Required:** `account_id`
**Optional:** `name`, `amount`, `date`, `nature` ("expense" or "income"), `notes`, `currency`, `category_id`, `merchant_id`, `tag_ids[]`

### GET /transactions
List/search transactions with filters.

```
curl -H "X-Api-Key: YOUR_KEY" \
  "http://35.227.53.189:3000/api/v1/transactions?per_page=10&type=expense&start_date=2026-03-01"
```

Filters: `search`, `account_id`, `category_id`, `merchant_id`, `start_date`, `end_date`, `min_amount`, `max_amount`, `type` (income/expense), `tag_ids[]`

### GET /transactions/:id
Get a single transaction.

### PATCH /transactions/:id
Update a transaction (same params as create, minus `account_id`).

### DELETE /transactions/:id
Delete a transaction.

### GET /usage
Check your rate limit status.

---

## Shortcut 1: Quick Expense ("Hey Siri, log expense")

This is the most useful shortcut. Say "Hey Siri, log expense" and it asks what you bought and how much, then logs it.

### Step-by-step build in Shortcuts app:

1. **Open Shortcuts app** → tap **+** → name it **"Log Expense"**

2. **Add action: Ask for Input**
   - Type: Text
   - Prompt: `What did you spend on?`
   - Save result as variable: `ExpenseName`

3. **Add action: Ask for Input**
   - Type: Number
   - Prompt: `How much?`
   - Save result as variable: `Amount`

4. **Add action: Get Current Date**
   - Format: Custom → `yyyy-MM-dd`
   - Save as variable: `Today`

5. **Add action: Text**
   - Content:
   ```
   {"transaction":{"account_id":REPLACE_WITH_YOUR_ACCOUNT_ID,"name":"ExpenseName","amount":Amount,"nature":"expense","date":"Today"}}
   ```
   - (Use the variable tokens from steps 2-4 — tap the variable name to insert them inline)
   - Save as variable: `Body`

6. **Add action: Get Contents of URL**
   - URL: `http://35.227.53.189:3000/api/v1/transactions`
   - Method: **POST**
   - Headers:
     - `X-Api-Key` = `06f6759f81817d90e1aad255bde3aaf2230ababdfc50679c63895a096deb2fa0`
     - `Content-Type` = `application/json`
   - Request Body: **File** → select `Body` variable

7. **Add action: Show Notification**
   - Title: `Logged!`
   - Body: `ExpenseName — $Amount`

### Siri trigger
- Go to shortcut settings (tap `...`) → **Add to Siri** → record phrase: **"Log expense"**

---

## Shortcut 2: Check Balances ("Hey Siri, my balances")

Shows all account balances at a glance.

### Steps:

1. **Name:** "My Balances"

2. **Add action: Get Contents of URL**
   - URL: `http://35.227.53.189:3000/api/v1/accounts`
   - Method: **GET**
   - Headers:
     - `X-Api-Key` = `06f6759f81817d90e1aad255bde3aaf2230ababdfc50679c63895a096deb2fa0`
   - Save result as: `Response`

3. **Add action: Get Dictionary Value**
   - Key: `accounts`
   - From: `Response`
   - Save as: `Accounts`

4. **Add action: Repeat with Each** (item in `Accounts`)
   - Inside the loop:
     - **Get Dictionary Value** → Key: `name` → save as `AccName`
     - **Get Dictionary Value** → Key: `balance` → save as `AccBal`
     - **Text**: `AccName: AccBal`
   - Save repeat results as: `Lines`

5. **Add action: Combine Text**
   - Input: `Lines`
   - Separator: New Line
   - Save as: `Summary`

6. **Add action: Show Result**
   - Text: `Summary`

### Siri trigger: **"My balances"**

---

## Shortcut 3: Log Income ("Hey Siri, log income")

Same as Log Expense but with `nature` set to `income`.

### Steps:

1. **Name:** "Log Income"

2. **Ask for Input** → Text → `What's the income from?` → `IncomeName`

3. **Ask for Input** → Number → `How much?` → `Amount`

4. **Get Current Date** → `yyyy-MM-dd` → `Today`

5. **Text:**
   ```
   {"transaction":{"account_id":REPLACE_WITH_YOUR_ACCOUNT_ID,"name":"IncomeName","amount":Amount,"nature":"income","date":"Today"}}
   ```

6. **Get Contents of URL**
   - URL: `http://35.227.53.189:3000/api/v1/transactions`
   - Method: POST
   - Headers: same as expense shortcut
   - Body: the Text from step 5

7. **Show Notification** → `Income logged: IncomeName — $Amount`

### Siri trigger: **"Log income"**

---

## Shortcut 4: Recent Transactions ("Hey Siri, recent spending")

Shows your last 5 transactions.

### Steps:

1. **Name:** "Recent Spending"

2. **Get Contents of URL**
   - URL: `http://35.227.53.189:3000/api/v1/transactions?per_page=5&type=expense`
   - Method: GET
   - Headers: API key header

3. **Get Dictionary Value** → Key: `transactions` → `Txns`

4. **Repeat with Each** (item in `Txns`):
   - Get `name` → `TxName`
   - Get `amount` → `TxAmt`
   - Get `date` → `TxDate`
   - **Text**: `TxDate  TxName  TxAmt`

5. **Combine Text** → New Line → `Summary`

6. **Show Result** → `Summary`

### Siri trigger: **"Recent spending"**

---

## Shortcut 5: Quick Expense with Category Picker

An enhanced version of Shortcut 1 that lets you pick a category.

### Steps:

1. **Name:** "Categorized Expense"

2. **Ask for Input** → Text → `What did you buy?` → `Name`

3. **Ask for Input** → Number → `How much?` → `Amount`

4. **Choose from Menu** → Prompt: `Category?`
   - Options: `Food`, `Transport`, `Shopping`, `Bills`, `Entertainment`, `Other`
   - Map each to a category_id from your Maybe instance (check your categories in the app first)

5. For each menu option, set a **Text** action with the matching `category_id`:
   - Food → `"category_id": 1`
   - Transport → `"category_id": 2`
   - etc.
   - Save as: `CatParam`

6. **Get Current Date** → `yyyy-MM-dd` → `Today`

7. **Text:**
   ```
   {"transaction":{"account_id":REPLACE_WITH_YOUR_ACCOUNT_ID,"name":"Name","amount":Amount,"nature":"expense","date":"Today",CatParam}}
   ```

8. **Get Contents of URL** → POST → same as before

9. **Show Notification** → `Name — $Amount`

### Siri trigger: **"Spend"**

---

## Setup Checklist

Before the shortcuts work, you need your **account_id**. Run this once:

```
curl -H "X-Api-Key: 06f6759f81817d90e1aad255bde3aaf2230ababdfc50679c63895a096deb2fa0" \
  http://35.227.53.189:3000/api/v1/accounts
```

Note down the `id` values. Replace `REPLACE_WITH_YOUR_ACCOUNT_ID` in each shortcut with the actual ID (e.g., your checking account's ID).

### Getting category IDs
Categories aren't exposed via API. Check them in the Maybe web app under Settings > Categories, or create transactions in the app first and then query them via the API to see the `category.id` values:

```
curl -H "X-Api-Key: 06f6759f81817d90e1aad255bde3aaf2230ababdfc50679c63895a096deb2fa0" \
  "http://35.227.53.189:3000/api/v1/transactions?per_page=50" | python3 -m json.tool
```

---

## Back Tap Setup (iPhone)

You can trigger any shortcut with a double or triple tap on the back of your iPhone:

1. **Settings** → **Accessibility** → **Touch** → **Back Tap**
2. **Double Tap** → scroll to bottom → select **"Log Expense"**
3. **Triple Tap** → select **"My Balances"** (optional)

Now double-tap the back of your phone to instantly log an expense.

---

## Apple Watch

All shortcuts above automatically appear on Apple Watch. Tap the Shortcuts complication or say "Hey Siri, log expense" from your wrist.

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| "Could not connect to server" | Make sure GCP VM is running and port 3000 is open in firewall |
| "401 Unauthorized" | Check your API key is correct and has `read_write` scope |
| "422 Unprocessable Entity" | Check required fields — `account_id` is required for transactions |
| Shortcut times out | Your VM might be sleeping. SSH in and run `docker compose up -d` |
| Wrong amounts | `nature: "expense"` stores positive amounts, `nature: "income"` stores negative |

---

## Tips

- **Automation:** In Shortcuts, create a **Personal Automation** → **Time of Day** → run "My Balances" every evening as a daily summary notification
- **Widget:** Add the "Log Expense" shortcut to your home screen (long press shortcut → Add to Home Screen)
- **NFC tags:** Buy cheap NFC stickers, program one with "Log Expense" via Shortcuts → Automation → NFC → tap to log
- **Focus mode:** Add the shortcut widget to a Finance-focused home screen
