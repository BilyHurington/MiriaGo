# Remote configuration

`anitabi-services.json` lets installed MiriaGo apps follow Anitabi when it
moves to a new domain, without a new app release.

The app reads it only when an Anitabi request fails in a way that suggests the
address changed (connection or TLS failure, 5xx, missing static data, or an HTML
page instead of JSON), rate-limited to 3 automatic checks per 24 hours, and when
the user taps "立即检查更新" in 设置 → 数据源设置 → Anitabi 服务地址. It is fetched
from, in order:

1. `https://raw.githubusercontent.com/BilyHurington/MiriaGo/main/config/anitabi-services.json`
2. `https://cdn.jsdelivr.net/gh/BilyHurington/MiriaGo@main/config/anitabi-services.json`
3. `https://fastly.jsdelivr.net/gh/BilyHurington/MiriaGo@main/config/anitabi-services.json`

jsDelivr caches `@main` for up to 12 hours; purge it after an urgent change:
`https://purge.jsdelivr.net/gh/BilyHurington/MiriaGo@main/config/anitabi-services.json`.

## Updating

1. Change the addresses under `services`. Every value must be a public HTTPS
   base URL without credentials, query or fragment (the same rules as the
   in-app address settings).
2. Increase `version`. Apps ignore a file whose `version` is not newer than the
   one they already use.
3. Update `updatedAt`.

Before switching, apps check that the new static data (`<staticData>/g.json`)
and API (`<api>/bangumi/115908/lite`) addresses actually respond; otherwise
they keep their current addresses. An address the user changed in the app
settings always takes precedence over this file. The file must stay under
16 KB and must not contain anything other than the fields above.
