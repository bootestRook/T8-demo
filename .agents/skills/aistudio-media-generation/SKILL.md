---
name: aistudio-media-generation
description: aistudio-media-generation can be used to generate images and videos. When users want to generate images or videos, please use this skill.
---

# Media Generation

Use this skill to call a configured media API and return generated media results.

When the user asks for generated media without naming a provider, prefer:

- image generation in this Godot V1 Plus template: `gpt-image-2`
- video generation: `seedance-video-2-0` (`Seedance 2.0`)

## Quick Start

Set runtime auth through environment variables. The bundled script
already defaults to `http://ai-studio.dodjoy.com:3001`, so you can use
the existing media API key:

PowerShell:

```powershell
$env:MEDIA_API_KEY = '<media-api-key>'
```

bash:

```bash
export MEDIA_API_KEY='<media-api-key>'
```

If `MEDIA_API_KEY` is missing, the script reads a Dodjoy login token
instead. For manual shell setup, use the shell-safe `X_DODJOY_TOKEN`;
the script-created Windows user variable is `X-DODJOY-TOKEN`. When both
exist, `X_DODJOY_TOKEN` wins so a current shell can override an older
saved Windows value. The script still sends the HTTP header as
`X-DODJOY-TOKEN`.

PowerShell:

```powershell
$env:X_DODJOY_TOKEN = '<dodjoy-token>'
```

bash:

```bash
export X_DODJOY_TOKEN='<dodjoy-token>'
```

If neither token exists, the script prompts the user to open
`http://auth.dodjoy.com/login?accessKey=1`, log in, and paste the copied
key into the local script prompt for this run only.
If the command is running non-interactively, tell the user to open the
same URL, set the copied key locally as `X_DODJOY_TOKEN`, and rerun the
command.

If the user has already pasted the copied Dodjoy key into chat, do not
echo it back. Pipe it through `--dodjoy-token-stdin` for the requested
command so it does not appear in command arguments. Persist it only
after the user explicitly confirms saving it to their user environment:

```powershell
'<dodjoy-token>' | python <skill-dir>/scripts/media_api.py --dodjoy-token-stdin generate --provider gpt-image-2 --prompt $prompt --options-file options.json --wait --output downloads
```

```powershell
'<dodjoy-token>' | python <skill-dir>/scripts/media_api.py save-dodjoy-token --token-stdin --yes
```

Python 3 is required to run the bundled script.

Override default routes only when the target API uses different endpoints:

PowerShell:

```powershell
$env:MEDIA_API_PROVIDERS_PATH = '/api/media/providers'
$env:MEDIA_API_GENERATE_PATH = '/api/media/generate'
$env:MEDIA_API_TASK_PATH_TEMPLATE = '/api/media/task/{taskId}'
$env:MEDIA_API_UPLOAD_PATH = '/files/upload'
```

bash:

```bash
export MEDIA_API_PROVIDERS_PATH='/api/media/providers'
export MEDIA_API_GENERATE_PATH='/api/media/generate'
export MEDIA_API_TASK_PATH_TEMPLATE='/api/media/task/{taskId}'
export MEDIA_API_UPLOAD_PATH='/files/upload'
```

Use the bundled script:

```powershell
python <skill-dir>/scripts/media_api.py providers
$prompt = 'a red fox in snow'
$options = '{"aspectRatio":"1:1"}'
$options | Set-Content options.json -Encoding UTF8
python <skill-dir>/scripts/media_api.py generate --provider gpt-image-2 --prompt $prompt --options-file options.json --options-file-delete-after --wait --output downloads
```

> **Windows PowerShell note**: Do not inline JSON in `--options` or long
> strings in `--prompt` on PowerShell 5.1. Prefer `--options-file` and
> `--prompt-file`, or assign the prompt to a variable first. The script
> now accepts UTF-8 files with or without BOM, so `Set-Content -Encoding UTF8`
> works reliably on Windows.

Read the narrowest reference first:

- Routes and auth: `references/api-surface.md`
- Provider choices, option handling, and contract catalog:
  `references/provider-rules.md`
- Task lifecycle and polling behavior: `references/implementation-map.md`

## Runtime Auth

Treat auth as runtime input, not static skill content.

- Use the script default base URL `http://ai-studio.dodjoy.com:3001`.
- Use `--base-url` only when the target environment differs.
- Prefer `MEDIA_API_KEY`; send it as `Authorization: Bearer <token>`.
- Auth precedence is `MEDIA_API_KEY` first, then
  `--dodjoy-token-stdin`, then explicit `--dodjoy-token`, then Dodjoy
  environment variables. For Dodjoy environment variables,
  `X_DODJOY_TOKEN` wins over `X-DODJOY-TOKEN`. The script sends Dodjoy
  auth as `X-DODJOY-TOKEN: <token>`. `--dodjoy-token` remains available
  for backward compatibility, but prefer stdin or environment variables
  so secrets do not appear in command arguments.
- If both auth values are missing, let the script prompt the user to
  open `http://auth.dodjoy.com/login?accessKey=1` and paste the
  copied key for this run only. Do not persist it unless the user
  explicitly confirms saving it.
- If the script is running non-interactively and cannot prompt, report
  the missing auth together with the same login URL and local env setup
  steps.
- If the user pastes a Dodjoy key into chat after logging in, do not
  print it, summarize it, or include it in command arguments. Pipe it
  to the requested command with `--dodjoy-token-stdin` unless the user
  explicitly asks to save it. Saving requires
  `save-dodjoy-token --token-stdin --yes`.
- If the target API uses a different auth header or prefix, pass `--auth-header` or `--auth-prefix` to the script instead of editing the skill.
- Never hardcode tokens in the skill, source files, or committed examples.
- Never print the full token back to the user.

If a required runtime value is missing and interactive login cannot run,
report exactly which value is missing and stop before making requests.

## Default Flow

1. If the provider is unclear, list providers first. In this Godot V1 Plus
   template, default to `gpt-image-2` for image generation and
   `seedance-video-2-0` (`Seedance 2.0`) for video generation.

```powershell
python <skill-dir>/scripts/media_api.py providers
```

2. When the provider is known and exact parameter names matter, fetch
   that provider's exact `options` schema from `/api/media/openapi.json`.

```powershell
python <skill-dir>/scripts/media_api.py provider-schema --provider gpt-image-2
```

3. Call the generate endpoint for the requested image or video.

```powershell
$prompt = 'a red fox in snow'
$options = '{"aspectRatio":"1:1"}'
$options | Set-Content options.json -Encoding UTF8
python <skill-dir>/scripts/media_api.py generate --provider gpt-image-2 --prompt $prompt --options-file options.json --options-file-delete-after --wait --output downloads
```

4. If the task is asynchronous, use `--wait` or call `wait` manually.

```powershell
python <skill-dir>/scripts/media_api.py wait --task-id "<task-id>" --provider gpt-image-2 --output downloads
```

5. Return the downloaded local file paths, the source media URLs, or the
   API error to the user.

The skill ships `references/provider-rules.md` with both the provider
selection rules and the contract-derived catalog of provider ids and
accepted `options` fields.

## Route Choice

Prefer these endpoint categories when the target API exposes them:

- provider or capability listing endpoint
- generation endpoint
- task status endpoint
- media OpenAPI or schema endpoint
- history endpoint only when the user asks about previous tasks

The script defaults to common media routes, but route paths are configurable:

- `--providers-path`
- `--generate-path`
- `--task-path-template`
- `--openapi-path`
- `--upload-path` (used when local/base64 reference images must be uploaded first)

Do not assume every project uses `/api/media/*`. Override routes when needed instead of patching the script.

## Option Handling

Pass provider options as JSON through `--options-file` or `--options`.

For image-to-image and image-to-video flows, the script now auto-uploads
non-URL image resources found in `options` before request assembly. This
applies to common image fields such as `imageUrl`, `imageUrls`,
`sourceImage`, `lastImageUrl`, and nested `imageInfos[].imageUrl`. Local
paths, `file://` URIs, data URIs, and raw base64 image strings are
uploaded to `--upload-path` (default `/files/upload`) and replaced with
returned URLs. Use `--disable-auto-upload-images` to turn this off.

Pass prompt text through `--prompt-file` or `--prompt`. For Windows
PowerShell, prefer `--prompt-file` for multi-line or quote-heavy prompts.

Pass project-specific request fields through `--extra-body-file` or
`--extra-body`.

Examples:

```powershell
$prompt = 'product photo of a ceramic cup'
$options = '{"size":"1536x1024"}'
$options | Set-Content options.json -Encoding UTF8
python <skill-dir>/scripts/media_api.py generate --provider image-model --prompt $prompt --options-file options.json --options-file-delete-after --wait --output downloads
```

Windows PowerShell pattern for long prompts:

```powershell
@'
a drone shot over a neon city
with cinematic lighting and rain reflections
'@ | Set-Content prompt.txt -Encoding UTF8

$options = '{"durationSeconds":8}'
$options | Set-Content options.json -Encoding UTF8
$body = '{"projectId":"demo"}'
$body | Set-Content body.json -Encoding UTF8

python <skill-dir>/scripts/media_api.py generate `
  --provider video-model `
  --prompt-file prompt.txt `
  --options-file options.json `
  --options-file-delete-after `
  --extra-body-file body.json `
  --wait `
  --output downloads

Remove-Item prompt.txt, body.json -ErrorAction SilentlyContinue
```

Do not guess provider-specific fields if they matter. Inspect
`references/provider-rules.md`, the target API's OpenAPI, or existing
API examples first. Prefer this order:

1. `/api/media/providers` for currently available providers
2. `/api/media/openapi.json` for exact provider `options` schema
3. bundled `references/provider-rules.md` as a fallback reference

## Notes

- The script supports `providers`, `generate`, `status`, and `wait`.
- The script supports `save-dodjoy-token --yes` for persisting a Dodjoy
  key after the user explicitly confirms saving it.
- The script also supports `provider-schema` for extracting exact
  provider `options` schema from `/api/media/openapi.json`.
- The script can override auth header, auth prefix, Dodjoy token, route
  paths, and extra request body fields at runtime. Use
  `--dodjoy-token-stdin` when passing a one-off token provided in chat.
- The script also supports `--base-url`, `--prompt-file`, `--output-file`,
  `--options-file-delete-after`, and `--extra-terminal-status`.
- The script auto-uploads local/base64 image resources in common
  `options.image*` fields to `/files/upload` before calling generate.
- `providers --include-option-schemas` can merge runtime provider
  availability with OpenAPI-derived parameter schemas in one response.
- Some projects return final media URLs immediately.
- Some projects return an accepted task with a `taskId` and require polling.
- Prefer `--output downloads` for generation tasks. It downloads media
  into the current working directory and returns local file paths plus
  source URLs.
- Use `--download-dir` only when the files should go somewhere other
  than the current working directory.
- Use `--output urls` only when the caller explicitly wants raw media
  URLs without downloading files.
- Use `--output urls+meta` when the caller needs both media URLs and
  the resulting `taskId`, for example in follow-up edit flows.

## Resources

### scripts/

- `scripts/media_api.py`
  - Lists providers
  - Calls the configured generate endpoint
  - Fetches task status
  - Waits for completion

## References

- `references/api-surface.md`
- `references/provider-rules.md`
- `references/implementation-map.md`
