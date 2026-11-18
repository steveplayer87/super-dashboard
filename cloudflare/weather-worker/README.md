# Super Dashboard Cloudflare Worker

This Worker proxies CWA forecasts without exposing the CWA token in the iOS bundle. Configure `CWA_API_KEY` and `DATABASE_WRITE_TOKEN` with `wrangler secret put`; do not commit either value. The weather icon SVGs are served from this Worker at `/api/weather-icons/{sun,cloud,rain}.svg`.

## API contract

- `GET /api/weather?city=臺北市&district=中正區` returns `{ city, district, temperature, weather, rainProbability, icon, iconUrl, updatedAt }`.
- `GET /api/database/items` returns `{ version: 1, items: [...] }` from the `DATABASE` KV namespace.
- `POST /api/database/items` accepts `{ "items": [...] }` (maximum 1,000 records) and requires `Authorization: Bearer <DATABASE_WRITE_TOKEN>`.

Database records use the shared JSON form `{ "id": "stable-id", "title": "display title", "data": { ... } }`. The app stores synchronized responses locally. A Notion automation or any webhook can publish this format to the authenticated POST endpoint; the Worker never evaluates HTML or JavaScript from records.

## Deployment

After Cloudflare OAuth, create a Workers KV namespace and replace the placeholder `id` in `wrangler.toml`. Then set both secrets in the Wrangler prompts and run `npx wrangler deploy` from this directory. Keep secret entry interactive; never put tokens on the command line or in files.
