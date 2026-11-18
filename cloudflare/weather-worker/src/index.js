const ICONS = {
  sun: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64"><circle cx="32" cy="32" r="13" fill="#ffd166"/><g stroke="#ffd166" stroke-width="4" stroke-linecap="round"><path d="M32 5v8M32 51v8M5 32h8M51 32h8M13 13l6 6M45 45l6 6M51 13l-6 6M19 45l-6 6"/></g></svg>',
  cloud: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64"><path fill="#c5d5e5" d="M17 49a13 13 0 1 1 3-25 17 17 0 0 1 33 7 10 10 0 0 1-3 18z"/></svg>',
  rain: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64"><path fill="#c5d5e5" d="M14 39a12 12 0 1 1 3-23 16 16 0 0 1 31 7 9 9 0 0 1-3 16z"/><g stroke="#75c9ff" stroke-width="4" stroke-linecap="round"><path d="m21 45-3 8m17-8-3 8m17-8-3 8"/></g></svg>'
};

function cors(origin) {
  return {
    'Access-Control-Allow-Origin': origin || '*',
    'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type,Authorization',
    'Access-Control-Max-Age': '86400',
    'Vary': 'Origin'
  };
}
function json(data, status, origin, extra = {}) {
  return new Response(JSON.stringify(data), { status: status || 200, headers: { ...cors(origin), 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store', ...extra } });
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const origin = request.headers.get('Origin') || '*';
    if (request.method === 'OPTIONS') return new Response(null, { headers: cors(origin) });

    const iconMatch = url.pathname.match(/^\/api\/weather-icons\/(sun|cloud|rain)\.svg$/);
    if (request.method === 'GET' && iconMatch) {
      return new Response(ICONS[iconMatch[1]], { headers: { ...cors(origin), 'Content-Type': 'image/svg+xml; charset=utf-8', 'Cache-Control': 'public, max-age=86400' } });
    }

    if (url.pathname === '/api/weather' && request.method === 'GET') {
      if (!env.CWA_API_KEY) return json({ error: 'weather_service_not_configured' }, 503, origin);
      const city = (url.searchParams.get('city') || '臺北市').slice(0, 12);
      const district = (url.searchParams.get('district') || '中正區').slice(0, 12);
      const upstream = new URL('https://opendata.cwa.gov.tw/api/v1/rest/datastore/F-D0047-061');
      upstream.searchParams.set('Authorization', env.CWA_API_KEY);
      upstream.searchParams.set('LocationName', district);
      upstream.searchParams.set('ElementName', '溫度,天氣現象,12小時降雨機率');
      const response = await fetch(upstream, { headers: { Accept: 'application/json' }, cf: { cacheTtl: 900, cacheEverything: true } });
      if (!response.ok) return json({ error: 'cwa_upstream_failed', status: response.status }, 502, origin);
      const body = await response.json();
      const location = body?.records?.Locations?.[0]?.Location?.find(x => x.LocationName === district) || body?.records?.Locations?.[0]?.Location?.[0];
      if (!location) return json({ error: 'cwa_location_missing' }, 502, origin);
      const element = (name) => location.WeatherElement?.find(x => x.ElementName === name)?.Time || [];
      const now = Date.now();
      const temperatures = element('溫度');
      const selected = temperatures.find(t => Date.parse(t.DataTime || t.StartTime) >= now) || temperatures[temperatures.length - 1];
      const temp = selected?.ElementValue?.[0]?.Temperature ?? selected?.ElementValue?.[0]?.value ?? null;
      const weather = element('天氣現象')[0]?.ElementValue?.[0]?.Weather ?? '多雲';
      const pop = element('12小時降雨機率')[0]?.ElementValue?.[0]?.ProbabilityOfPrecipitation ?? '0';
      const rainy = /雨|雷/.test(weather) || Number(pop) >= 35;
      const icon = rainy ? 'rain' : (/晴/.test(weather) ? 'sun' : 'cloud');
      return json({ city, district, temperature: temp === null ? null : Number(temp), weather, rainProbability: Number(pop) || 0, icon, iconUrl: `${url.origin}/api/weather-icons/${icon}.svg`, updatedAt: new Date().toISOString() }, 200, origin, { 'Cache-Control': 'public, max-age=900' });
    }

    if (url.pathname === '/api/database/items' && request.method === 'GET') {
      const stored = await env.DATABASE.get('items', 'json');
      return json({ version: 1, items: Array.isArray(stored) ? stored : [] }, 200, origin);
    }
    if (url.pathname === '/api/database/items' && request.method === 'POST') {
      if (!env.DATABASE_WRITE_TOKEN || request.headers.get('Authorization') !== `Bearer ${env.DATABASE_WRITE_TOKEN}`) return json({ error: 'unauthorized' }, 401, origin);
      let body;
      try { body = await request.json(); } catch { return json({ error: 'invalid_json' }, 400, origin); }
      const items = Array.isArray(body) ? body : body?.items;
      if (!Array.isArray(items) || items.length > 1000) return json({ error: 'items_must_be_array_max_1000' }, 400, origin);
      await env.DATABASE.put('items', JSON.stringify(items));
      return json({ version: 1, count: items.length, updatedAt: new Date().toISOString() }, 200, origin);
    }
    return json({ error: 'not_found' }, 404, origin);
  }
};
