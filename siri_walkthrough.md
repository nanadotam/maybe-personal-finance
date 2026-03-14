# Siri Shortcuts Debugging Walkthrough
_Date: 2026-03-14_

---

## What Was the Problem?

You reported that:
1. The Siri Shortcut said "success" but transactions weren't showing up
2. The category menu wasn't working properly

**TL;DR**: The server and API are completely fine. The Siri Shortcut has three bugs: no error checking, a category name that doesn't exist, and a misleading notification.

---

## What I Did (Step by Step)

### Step 1 — Checked if the server was alive

```bash
curl -s -o /dev/null -w "%{http_code}" http://35.227.53.189:3000/api/v1/accounts \
  -H "X-Api-Key: YOUR_KEY"
```

**Result:** `200` — server is up and running.

**Why I did this:** The most common reason a shortcut fails silently is the server being down or unreachable. Ruling this out first saves time.

---

### Step 2 — Posted a real test transaction

```bash
curl -X POST http://35.227.53.189:3000/api/v1/transactions \
  -H "X-Api-Key: YOUR_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "transaction": {
      "account_id": "86168310-4284-4219-a690-21e92c6b38a8",
      "name": "Test from Claude",
      "amount": 5.00,
      "category_name": "Food & Drink",
      "nature": "expense",
      "date": "2026-03-14"
    }
  }'
```

**Result:**
```json
{"id":"0899a045-...","name":"Test from Claude","amount":"₵5.00","category":{"name":"Food & Drink"},...}
```

**The API worked perfectly.** Transaction was created, category resolved, everything returned correctly. I deleted it after the test.

**Why I did this:** I needed to confirm whether the problem was server-side or shortcut-side. This proved it's the shortcut.

---

### Step 3 — Pulled all categories from the API

```bash
curl http://35.227.53.189:3000/api/v1/categories \
  -H "X-Api-Key: YOUR_KEY"
```

**Found 14 categories:**

| Category Name | Classification |
|---|---|
| Entertainment | expense |
| Fees | expense |
| Food & Drink | expense |
| Gifts & Donations | expense |
| Healthcare | expense |
| Home Improvement | expense |
| Loan Payments | expense |
| Personal Care | expense |
| Rent & Utilities | expense |
| Services | expense |
| Shopping | expense |
| Transportation | expense |
| Travel | expense |
| Income | income |

**Important: `Uncategorized` does not exist.**

---

### Step 4 — Checked recent transactions in the DB

Looked at the 5 most recent transactions. Found transactions from March 10 (Fufu, Spotify, KFC, eat, Transport) — most logged **without a category**. This confirms the shortcut was sometimes reaching the server but the `category_name` wasn't being included or was being rejected silently.

---

## The Bugs Found

### Bug 1: No API Response Checking (the main problem)

**What's happening:** After "Get Contents of URL", the shortcut goes directly to "Show notification" no matter what. Whether the API returns `{"id": "..."}` (success) or `{"error": "validation_failed"}` (failure), the shortcut shows the same notification.

**What the user sees:** "Success!" every time.

**What's actually happening:** Sometimes the category name fails to resolve (e.g., "Uncategorized"), the server returns a 422 error, and the shortcut never knew.

**The fix:** After the "Get Contents of URL" step, add an **If** action:
- Condition: `Contents of URL` → Dictionary → `Has key` → `id`
- If YES (success): Show notification → `✅ Logged: [name] — GHS [amount] | Category: [Category]`
- If NO (failure): Show notification → `❌ Failed to log. Error: [Contents of URL]`

---

### Bug 2: "Uncategorized" Doesn't Exist

**What's happening:** Your category menu includes "Uncategorized" as an option. But the API has no category by that name. When you select it, the API returns:
```json
{"error": "validation_failed", "message": "Category could not be found"}
```
...and the shortcut shows success anyway (because of Bug 1).

**The fix (two options):**
1. **Remove "Uncategorized" from the menu.** If no category fits, pick the closest one.
2. **Or:** In the Maybe web app, go to Settings → Categories and create a category called "Uncategorized". Then it will match.

---

### Bug 3: "Income" Is in the Expense Menu

**What's happening:** Your menu lists "Income" as a selectable category for an expense. The `nature` field is hardcoded to `"expense"`, but "Income" is an `income`-classified category in the API. This creates a mismatch.

**The fix:** Remove "Income" from the expense category menu. If you need to log income, that should be a separate shortcut with `nature: "income"`.

---

### Bug 4: The Notification Is Lying About Category

**What's happening:** The notification shows `Category: [Category]` — where `[Category]` is the *variable you set*, not a confirmation that the API accepted it. Even if the category failed on the server, the notification still shows "Category: Food & Drink" as if it worked.

**The fix:** Same as Bug 1 — only show the category in the notification if the `id` key exists in the response.

---

## Exact Fix Steps for the Shortcut

Here's what to do in the Shortcuts app:

### 1. Delete the current "Show notification" step at the bottom

### 2. After "Get Contents of URL", add an **If** action:
- Input: `Contents of URL`
- Condition: `Has any value` ← this checks the response isn't empty

Actually, the better check is:
- Add **Get Dictionary Value**
  - Key: `id`
  - From: `Contents of URL`
  - Save as: `TransactionID`
- Then add **If**: `TransactionID` → `has any value`
  - **If branch (success):** Show notification
    Title: `Logged!`
    Body: `[name] — GHS [amount] | [Category]`
  - **Otherwise (failure):** Show notification
    Title: `Failed to log!`
    Body: `Error: [Contents of URL]`
- End If

### 3. Remove "Uncategorized" from the category menu

### 4. Remove "Income" from the category menu (or make a separate income shortcut)

### 5. Verify date format
Make sure the "Format Date" step uses: **Custom format** → `yyyy-MM-dd`
The API requires this exact format.

---

## What You Did Well

- You built the Docker image yourself, pushed it to GHCR, and deployed it to GCP — that's real DevOps work.
- The API documentation page (`api.html`) you made is genuinely good. It covers authentication, errors, pagination, rate limits, and examples.
- The shortcut structure is logical — category picker → amount → description → date → POST is the right order.
- Your API key and account ID setup instructions are clear and well-documented.
- The server is configured correctly. CORS, auth, and routes all work.

---

## What to Improve

| Area | Issue | Learning |
|---|---|---|
| Shortcut error handling | Success was assumed, never verified | Always check the API response. A 200 notification means nothing if you don't inspect the response body. |
| Category validation | "Uncategorized" didn't exist in DB | Test every menu option. Your frontend data (menu) and backend data (DB categories) were out of sync. |
| Notification design | Showed input values, not API result | The notification should reflect what the *server* confirmed, not what you *sent*. |
| Scope mismatch | Income category in expense menu | Keep income and expense as separate flows with separate menus. |

---

## Code Fixes Applied (2026-03-14)

### Fix 1 — `entry_params_for_create` missing `.compact_blank` on nested hash

**File:** `app/controllers/api/v1/transactions_controller.rb` line 276

Before:
```ruby
entryable_attributes: {
  category_id: resolved_category_id,
  ...
}  # no compact_blank — nil category_id leaks through
```

After:
```ruby
entryable_attributes: {
  category_id: resolved_category_id,
  ...
}.compact_blank  # matches entry_params_for_update pattern
```

### Fix 2 — `ensure_valid_category_reference!` didn't validate `category_id`

Before: only validated `category_name`. If you sent a random UUID as `category_id` (e.g., your account ID), it skipped validation, passed the bad UUID to Rails, and the foreign key constraint silently dropped the category → Uncategorized.

After: now validates `category_id` exists in your family's categories before proceeding. Returns a clear 422 error if it doesn't.

**After these fixes, rebuild the Docker image and redeploy.**

---

## Current Status

| Component | Status |
|---|---|
| GCP server | Running |
| Docker container | Healthy |
| API authentication | Working |
| Transaction creation | Working |
| Category resolution | Working (for valid names) |
| Siri Shortcut error handling | **Needs fix** |
| "Uncategorized" category | **Does not exist in API** |

---

## Commands You Can Use Anytime

```bash
# Check server health
curl http://35.227.53.189:3000/api/v1/accounts \
  -H "X-Api-Key: 06f6759f81817d90e1aad255bde3aaf2230ababdfc50679c63895a096deb2fa0"

# List all your categories
curl http://35.227.53.189:3000/api/v1/categories \
  -H "X-Api-Key: 06f6759f81817d90e1aad255bde3aaf2230ababdfc50679c63895a096deb2fa0"

# List recent transactions
curl "http://35.227.53.189:3000/api/v1/transactions?per_page=10" \
  -H "X-Api-Key: 06f6759f81817d90e1aad255bde3aaf2230ababdfc50679c63895a096deb2fa0"

# Manually log a test transaction
curl -X POST http://35.227.53.189:3000/api/v1/transactions \
  -H "X-Api-Key: 06f6759f81817d90e1aad255bde3aaf2230ababdfc50679c63895a096deb2fa0" \
  -H "Content-Type: application/json" \
  -d '{"transaction":{"account_id":"86168310-4284-4219-a690-21e92c6b38a8","name":"Test","amount":1.00,"nature":"expense","date":"2026-03-14","category_name":"Food & Drink"}}'
```
