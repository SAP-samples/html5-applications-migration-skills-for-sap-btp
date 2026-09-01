---
name: sap-help-to-github
description: Use when the user provides a help.sap.com URL and wants to read its content — converts SAP BTP Help Portal URLs to raw GitHub Markdown without a browser, API key, or authentication.
---

# SAP Help Portal → GitHub Markdown

SAP BTP documentation is published to a public GitHub repo (`SAP-docs/btp-cloud-platform`). Any `help.sap.com/docs/btp/sap-business-technology-platform/*` page can be read as clean Markdown using 2 unauthenticated API calls.

## Why not WebFetch?

The SAP Help Portal is a JavaScript SPA — WebFetch returns only an empty shell. This approach needs no browser and no API key.

## How it works

```
help.sap.com/docs/btp/sap-business-technology-platform/<slug>
                                                        ^^^^
                                               1. extract slug
                                               2. SAP metadata API → topicLoio (first 7 chars = hash)
                                               3. GitHub tree API → find docs/<folder>/<slug>-<hash>.md
                                               4. fetch raw.githubusercontent.com
```

## One-liner (copy-paste)

Replace `SLUG` with the last path segment of the Help Portal URL:

```bash
SLUG="set-up-your-application-for-multitenancy"

# Step 1: resolve hash from SAP metadata API (no auth)
LOIO=$(curl -s "https://help.sap.com/http.svc/deliverableMetadata?product_url=btp&topic_url=${SLUG}&version=LATEST&deliverable_url=sap-business-technology-platform" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['topicLoio'])")
HASH="${LOIO:0:7}"

# Step 2: find file path via single GitHub tree API call (no auth, public repo)
FILE_PATH=$(curl -s "https://api.github.com/repos/SAP-docs/btp-cloud-platform/git/trees/main?recursive=1" \
  | python3 -c "
import sys, json
h = '${HASH}'
for item in json.load(sys.stdin).get('tree', []):
    if h in item.get('path', '') and item['path'].endswith('.md'):
        print(item['path'])
        break
")

# Step 3: fetch raw markdown
curl -s "https://raw.githubusercontent.com/SAP-docs/btp-cloud-platform/main/${FILE_PATH}"
```

## Scope

| | |
|---|---|
| Works for | `help.sap.com/docs/btp/sap-business-technology-platform/*` |
| GitHub repo | `SAP-docs/btp-cloud-platform` (public) |
| Auth needed | None |
| API calls | 3 total (metadata + tree + raw fetch) |
| Rate limit | GitHub unauthenticated: 60 req/hour — run `curl -s https://api.github.com/rate_limit` to check |

For other SAP products, search for the matching repo under the `SAP-docs` GitHub org.

## Common mistakes

| Mistake | Fix |
|---|---|
| Using full URL as slug | Extract only the last path segment |
| `truncated: true` in tree response | Repo got large — fall back to per-folder Contents API scan on `docs/` subdirs |
| SAP metadata API returns no `topicLoio` | The page may use a different product URL — inspect network tab to find correct `product_url` param |
