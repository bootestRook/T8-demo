# API Surface

## Purpose

Use this reference when the user wants media output now and the target API already exposes routes for image or video generation.

## Endpoint categories

Most media APIs expose some subset of these endpoints:

- provider or capability listing
- file upload endpoint (when reference images are local/base64 resources)
- media generation
- task status polling
- OpenAPI or schema discovery
- task history

The exact path names vary. Discover the local route names before sending requests or override them through script flags or env vars.

## Typical generate request

Most media generation requests contain:

- `provider`
- `prompt`
- `options`
- optional reference inputs such as `imageUrls` or `videoUrls`
- optional business context such as chat, workflow, project, or message ids

For image-to-image and image-to-video requests, local/base64 image
resources should be uploaded first and converted to URL strings before
building final `options`.

## Typical response patterns

Synchronous response:

- `status` is already complete
- media URLs are returned immediately

Asynchronous response:

- request is accepted
- response contains a `taskId` or provider task identifier
- media URLs appear only after polling the task endpoint

## Auth and route overrides

Treat auth as runtime input:

- default env vars:
  - `MEDIA_API_KEY`
  - `X_DODJOY_TOKEN` on any shell, or `X-DODJOY-TOKEN` from the saved Windows user environment
  - `MEDIA_API_PROVIDERS_PATH`
  - `MEDIA_API_GENERATE_PATH`
  - `MEDIA_API_TASK_PATH_TEMPLATE`
  - `MEDIA_API_UPLOAD_PATH`
- the bundled script already defaults to
  `http://ai-studio.dodjoy.com:3001`
- use `--base-url` only when the target environment differs
- prefer `MEDIA_API_KEY` and send it as `Authorization: Bearer <token>`
- auth precedence is `MEDIA_API_KEY`, then `--dodjoy-token-stdin`, then
  explicit `--dodjoy-token`, then Dodjoy environment variables. For
  Dodjoy environment variables, `X_DODJOY_TOKEN` wins over
  `X-DODJOY-TOKEN`. The script sends Dodjoy auth as
  `X-DODJOY-TOKEN: <token>`. `--dodjoy-token` remains available for
  backward compatibility, but prefer stdin or environment variables so
  secrets do not appear in command arguments.
- if no auth is configured, the script prompts the user to open
  `http://auth.dodjoy.com/login?accessKey=1`, paste the copied key,
  and uses it for this run only
- if the script cannot prompt, report the same login URL and local env
  setup commands
- if the user has already pasted the Dodjoy key into chat, do not echo it
  back or put it in command arguments; pipe it to the requested command
  with `--dodjoy-token-stdin` unless the user explicitly confirms saving
  it. Persistence requires `save-dodjoy-token --token-stdin --yes`
- if the target API uses a different auth header or prefix, override them with `--auth-header` and `--auth-prefix`

The bundled script auto-uploads local/base64 image resources in common
`options.image*` fields to `--upload-path` (default `/files/upload`) and
replaces them with URLs before calling the generate endpoint.

## Direct request template

```powershell
curl.exe -X POST "<base-url><generate-route>" `
  -H "Authorization: Bearer <api-key>" `
  -H "Content-Type: application/json" `
  -d "{\"provider\":\"<provider>\",\"prompt\":\"<prompt>\",\"options\":{}}"
```

Dodjoy token auth template:

```powershell
curl.exe -X POST "<base-url><generate-route>" `
  -H "X-DODJOY-TOKEN: <dodjoy-token>" `
  -H "Content-Type: application/json" `
  -d "{\"provider\":\"<provider>\",\"prompt\":\"<prompt>\",\"options\":{}}"
```

## Script template

Provider discovery and exact schema lookup:

```powershell
python <skill-dir>/scripts/media_api.py providers
python <skill-dir>/scripts/media_api.py provider-schema --provider tencent-nano-banana2
python <skill-dir>/scripts/media_api.py providers --include-option-schemas
```

Recommended for Windows PowerShell:

```powershell
$prompt = 'a red fox in snow'
$options = '{"aspectRatio":"1:1"}'
$options | Set-Content options.json -Encoding UTF8

python <skill-dir>/scripts/media_api.py generate `
  --provider "<provider>" `
  --prompt $prompt `
  --options-file options.json `
  --options-file-delete-after `
  --wait `
  --output downloads
```

`--output downloads` saves generated media into the current working
directory and returns the downloaded local file paths plus source URLs.
Use `--download-dir` to override the target directory when needed.

For long or multi-line prompts on Windows PowerShell, prefer
`--prompt-file`:

```powershell
@'
<your prompt here>
'@ | Set-Content prompt.txt -Encoding UTF8

python <skill-dir>/scripts/media_api.py generate `
  --provider "<provider>" `
  --prompt-file prompt.txt `
  --options-file options.json `
  --options-file-delete-after `
  --wait `
  --output downloads

Remove-Item prompt.txt -ErrorAction SilentlyContinue
```

Simple bash example:

```bash
python <skill-dir>/scripts/media_api.py generate \
  --provider "<provider>" \
  --prompt "<prompt>" \
  --options '{"aspectRatio":"1:1"}' \
  --wait \
  --output downloads
```

## How To Use OpenAPI

Use `/api/media/providers` to answer "what is available now".

Use `/api/media/openapi.json` to answer "what fields does this provider's
`options` object accept".

The bundled script exposes this through:

- `provider-schema --provider <provider-id>` for one provider
- `providers --include-option-schemas` to merge availability plus schema

OpenAPI-derived schemas are better for exact field names and enum values.
Provider listing is better for display names, media type, features, and
runtime availability.

## Discovery checklist

```bash
rg -n "generate|providers|capabilities|task status|history|openapi|swagger" .
```
