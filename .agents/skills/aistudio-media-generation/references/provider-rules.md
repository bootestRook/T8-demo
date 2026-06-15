# Provider Rules

Use this reference when the user wants to choose a provider or when
provider options are unclear. This file also includes the
contract-derived provider catalog for provider ids and accepted
`options` fields.

## Choose a provider

If the user does not name a provider:

- list providers or inspect capability docs first
- prefer runtime `/api/media/providers` over static catalogs when available
- use the catalog in this file as the contract reference for provider ids and `options` fields, but do not assume server availability from the contract alone
- prefer `gpt-image-2` for image requests in this Godot V1 Plus template when the target API exposes it
- prefer `seedance-video-2-0` (`Seedance 2.0`) for video requests when the target API exposes it
- otherwise prefer image-first providers for image requests
- otherwise prefer video-first providers for video requests
- prefer providers that explicitly accept reference media when the user supplies image or video inputs

## Prompt rules

Do not assume every provider always requires a prompt.

Common exceptions:

- image-to-image mode
- reference-video mode
- character or style presets
- providers where prompt is optional only for some models or modes

## Options

- Keep provider options as JSON.
- Do not guess field names if they affect behavior.
- Prefer `/api/media/openapi.json` or `provider-schema` output over this
  static file when exact runtime parameter names matter.
- Inspect OpenAPI, provider docs, or existing requests before sending a payload.
- Reuse the target API's existing field names for reference inputs such as `imageUrls`, `videoUrls`, `imageUrl`, or `model`.
- For image-to-image and image-to-video flows, upload local/base64 image
  resources first and convert them into URL strings before final options
  assembly.
- Use `--extra-body` or `--extra-body-file` for project-specific top-level fields such as `chatId`, `workflowId`, `messageId`, or reference objects that do not belong inside `options`.

## Common option patterns

- output size or resolution
- duration for video
- aspect ratio
- model
- quality
- reference images or videos
- seed or variation controls

## Failure patterns

Provider call fails early:

- unsupported provider id
- missing required prompt
- option schema mismatch
- reference input shape mismatch

Provider accepts request but produces poor output:

- wrong model or generation mode
- incompatible aspect ratio or duration
- missing reference media
- provider chosen for the wrong media type

## Discovery checklist

```bash
rg -n "provider|options schema|promptRequired|generationMode|model" .
```

## Contract Catalog

Contract-derived catalog for media providers and accepted `options`
fields.

### Provider Enums

- Image (14): `gpt-image-2`, `midjourney`,
  `baidu-enhance`, `nano-banana`, `baidu-nano-banana`,
  `baidu-nano-banana2`, `seedream-image`,
  `seedream-image-5-0-lite`, `wanxiang-image`,
  `youchuan-image`, `tencent-nano-banana`,
  `tencent-nano-banana2`, `holopix-image`,
  `nano-banana2`
- Video (21): `jimeng-video`,
  `jimeng-action-imitation`, `keling-action-imitation`,
  `veo3`, `tencent-veo3`, `seedance-video-2-0`,
  `seedance-video-2-0-fast`, `seedance-video-1-5`,
  `seedance-video-1-0`, `keling-video`, `keling-ko1`,
  `midjourney-video`, `vidu-video`, `hailuo-video`,
  `sora2-video`, `sora2-video-by-azure`,
  `wanxiang-video`, `wanxiang-video-2-6`,
  `volcengine-visual`, `youchuan-video`,
  `volcengine-visual-digital-human`, `hunyuan`
- Audio (2): `volcengine-tts`, `noiz-tts`

### Common Notes

- Most providers accept optional operational fields `_skipQueue`
  and `taskId` inside `options`.
- Requiredness below is contract-level requiredness for
  `options.*`, not business-level prompt rules.
- Where `model-spec.ts` defines generation modes, they are listed
  under the provider.

### Image Providers

#### `gpt-image-2`

| Field | Required | Contract Type |
| --- | --- | --- |
| `n` | No | number (min 1, max 4) |
| `size` | No | enum(auto \| 1024x1024 \| 1536x1024 \| 1024x1536) |
| `quality` | No | enum(auto \| high \| medium \| low) |
| `background` | No | enum(auto \| transparent \| opaque) |
| `format` | No | enum(png \| jpeg) |
| `compression` | No | number (min 0, max 100) |
| `mask` | No | string |
| `imageUrls` | No | string[] |
| `_skipQueue` | No | boolean |
| `taskId` | No | string |

#### `midjourney`

| Field | Required | Contract Type |
| --- | --- | --- |
| `version` | No | string |
| `mode` | No | string |
| `speed` | No | enum(--fast \| --relax \| --turbo) |
| `aspectRatio` | No | string |
| `stylization` | No | number |
| `weirdness` | No | number |
| `variety` | No | number |
| `chaos` | No | number |
| `quality` | No | string |
| `style` | No | string |
| `seed` | No | number |
| `stop` | No | number (min 10, max 100) |
| `tile` | No | boolean |
| `video` | No | boolean |
| `repeat` | No | number (min 1, max 10) |
| `getUImages` | No | boolean |
| `_skipQueue` | No | boolean |
| `taskId` | No | string |
| `jobId` | No | string |
| `mask` | No | string |
| `apiType` | No | enum(generations \| edits \| action \| describe) |
| `action` | No | string |
| `components` | No | string[] |
| `index` | No | number |
| `imageUrls` | No | string[] |
| `no` | No | string |

#### `baidu-enhance`

| Field | Required | Contract Type |
| --- | --- | --- |
| `apiType` | No | enum(generations \| edits \| action \| describe) |
| `imageUrls` | Yes | string[] (minItems 1) |
| `_skipQueue` | No | boolean |
| `taskId` | No | string |

#### `nano-banana`

| Field | Required | Contract Type |
| --- | --- | --- |
| `seed` | No | number |
| `aspectRatio` | No | enum(1:1 \| 2:3 \| 3:2 \| 3:4 \| 4:3 \| 4:5 \| 5:4 \| 9:16 \| 16:9 \| 21:9) |
| `outputFormat` | No | enum(png \| jpeg) |
| `numberOfImages` | No | number |
| `imageUrls` | No | string[] |
| `_skipQueue` | No | boolean |
| `taskId` | No | string |
| `no` | No | string |
| `resolution` | No | string |

#### `baidu-nano-banana`

| Field | Required | Contract Type |
| --- | --- | --- |
| `seed` | No | number |
| `aspectRatio` | No | enum(1:1 \| 2:3 \| 3:2 \| 3:4 \| 4:3 \| 4:5 \| 5:4 \| 9:16 \| 16:9 \| 21:9) |
| `outputFormat` | No | enum(png \| jpeg) |
| `numberOfImages` | No | number |
| `imageUrls` | No | string[] |
| `_skipQueue` | No | boolean |
| `taskId` | No | string |
| `no` | No | string |
| `resolution` | No | string |

#### `baidu-nano-banana2`

| Field | Required | Contract Type |
| --- | --- | --- |
| `seed` | No | number |
| `aspectRatio` | No | enum(1:1 \| 2:3 \| 3:2 \| 3:4 \| 4:3 \| 4:5 \| 5:4 \| 9:16 \| 16:9 \| 21:9) |
| `outputFormat` | No | enum(png \| jpeg) |
| `numberOfImages` | No | number |
| `imageUrls` | No | string[] |
| `_skipQueue` | No | boolean |
| `taskId` | No | string |
| `no` | No | string |
| `resolution` | No | string |

#### `seedream-image`

| Field | Required | Contract Type |
| --- | --- | --- |
| `aspectRatio` | No | string |
| `outputFormat` | No | enum(png \| jpeg) |
| `imageUrls` | No | string[] |
| `size` | No | string |
| `sequential` | No | enum(disabled \| auto) |
| `sequentialMaxImages` | No | number (int, min 1, max 15) |
| `watermark` | No | boolean |
| `tools` | No | { type: enum(web_search) }[] |
| `_skipQueue` | No | boolean |
| `taskId` | No | string |

#### `seedream-image-5-0-lite`

| Field | Required | Contract Type |
| --- | --- | --- |
| `aspectRatio` | No | string |
| `outputFormat` | No | enum(png \| jpeg) |
| `imageUrls` | No | string[] |
| `size` | No | string |
| `sequential` | No | enum(disabled \| auto) |
| `sequentialMaxImages` | No | number (int, min 1, max 15) |
| `watermark` | No | boolean |
| `tools` | No | { type: enum(web_search) }[] |
| `_skipQueue` | No | boolean |
| `taskId` | No | string |

#### `wanxiang-image`

| Field | Required | Contract Type |
| --- | --- | --- |
| `negativePrompt` | No | string |
| `no` | No | string |
| `seed` | No | number (min -1, max 18446744073709552000), default -1 |
| `n` | No | number, default 1 |
| `watermark` | No | boolean, default false |
| `prompt_extend` | No | boolean, default true |
| `aspect_ratio` | No | enum(16:9 \| 9:16 \| 1:1 \| 4:3 \| 3:4 \| 21:9 \| 2:3 \| 3:2), default "16:9" |
| `_skipQueue` | No | boolean |
| `taskId` | No | string |

#### `youchuan-image`

| Field | Required | Contract Type |
| --- | --- | --- |
| `apiType` | No | enum(diffusion \| variation \| upscale \| reroll \| pan \| outpaint \| inpaint \| remix \| edit \| upload-paint \| retexture \| remove-background \| enhance), default "diffusion" |
| `jobId` | No | string |
| `imageIndex` | No | number (int, min 0, max 3) |
| `imageUrl` | No | string |
| `imageUrls` | No | string[] |
| `direction` | No | enum(left \| right \| up \| down) |
| `mask` | No | string \| { areas?: any[]; url?: string } |
| `imgPos` | No | { x: number; y: number; width: number; height: number } |
| `canvas` | No | { width: number; height: number } |
| `callback` | No | string |
| `version` | No | string |
| `mode` | No | string |
| `speed` | No | enum(--fast \| --relax \| --turbo) |
| `aspectRatio` | No | string |
| `stylization` | No | number |
| `weirdness` | No | number |
| `variety` | No | number |
| `chaos` | No | number |
| `quality` | No | string |
| `style` | No | string |
| `seed` | No | number |
| `stop` | No | number (min 10, max 100) |
| `tile` | No | boolean |
| `video` | No | boolean |
| `repeat` | No | number (min 1, max 10) |
| `getUImages` | No | boolean |
| `no` | No | string (min 1) |
| `_skipQueue` | No | boolean |
| `taskId` | No | string |

#### `tencent-nano-banana`

| Field | Required | Contract Type |
| --- | --- | --- |
| `modelName` | No | string |
| `prompt` | No | string |
| `negativePrompt` | No | string |
| `enhancePrompt` | No | boolean |
| `aspectRatio` | No | string |
| `resolution` | No | string |
| `imageUrl` | No | string |
| `imageUrls` | No | string[] |
| `imageInfos` | No | { imageUrl: string; referenceType?: string }[] |
| `extraParameters` | No | Record<string, any> |
| `_skipQueue` | No | boolean |
| `taskId` | No | string |

#### `tencent-nano-banana2`

| Field | Required | Contract Type |
| --- | --- | --- |
| `modelName` | No | string |
| `prompt` | No | string |
| `negativePrompt` | No | string |
| `enhancePrompt` | No | boolean |
| `aspectRatio` | No | string |
| `resolution` | No | string |
| `imageUrl` | No | string |
| `imageUrls` | No | string[] |
| `imageInfos` | No | { imageUrl: string; referenceType?: string }[] |
| `extraParameters` | No | Record<string, any> |
| `_skipQueue` | No | boolean |
| `taskId` | No | string |

#### `holopix-image`

| Field | Required | Contract Type |
| --- | --- | --- |
| `modelDetailList` | No | { modelId: number (int, min 0); strength?: number (min 0, max 1), default 1 }[] (maxItems 5) |
| `negativePrompt` | No | string (max 500) |
| `seed` | No | number (int) |
| `imageGuidanceWeights` | No | number (min 0, max 6) |
| `aspectRatios` | No | enum(16:9 \| 9:16 \| 1:1 \| 4:3 \| 3:4 \| 3:2 \| 2:3 \| 21:9) |
| `faceDetail` | No | boolean |
| `hdFix` | No | boolean |
| `hdScale` | No | number |
| `simpleBackground` | No | boolean |
| `enablePerturb` | No | boolean |
| `perturb` | No | number (min 0, max 5) |
| `characterPose` | No | string |
| `batchSize` | No | number (int, min 1, max 4) |
| `imageReference` | No | string |
| `referenceMode` | No | enum(standard \| color) |
| `referenceWeight` | No | number (min 0, max 1) |
| `sourceImage` | No | string |
| `imageUrls` | No | string[] |
| `imageMode` | No | enum(linerSketch \| colorSketch) |
| `imageColor` | No | boolean |
| `imageWeight` | No | number (min 0, max 1) |
| `_skipQueue` | No | boolean |
| `taskId` | No | string |

#### `nano-banana2`

| Field | Required | Contract Type |
| --- | --- | --- |
| `seed` | No | number |
| `aspectRatio` | No | enum(1:1 \| 2:3 \| 3:2 \| 3:4 \| 4:3 \| 4:5 \| 5:4 \| 9:16 \| 16:9 \| 21:9) |
| `outputFormat` | No | enum(png \| jpeg) |
| `numberOfImages` | No | number |
| `imageUrls` | No | string[] |
| `_skipQueue` | No | boolean |
| `taskId` | No | string |
| `no` | No | string |
| `resolution` | No | string |

### Video Providers

#### `jimeng-video`

| Field | Required | Contract Type |
| --- | --- | --- |
| `aspect_ratio` | No | enum(16:9 \| 9:16 \| 1:1 \| 4:3 \| 3:4 \| 21:9), default "16:9" |
| `seed` | No | number (min -1, max 18446744073709552000), default -1 |
| `imageUrls` | No | string[] |
| `_skipQueue` | No | boolean |
| `taskId` | No | string |

#### `jimeng-action-imitation`

| Field | Required | Contract Type |
| --- | --- | --- |
| `req_key` | No | string, default "jimeng_dream_actor_m1_gen_video_cv" |
| `imageUrl` | Yes | string |
| `videoUrl` | Yes | string |
| `_skipQueue` | No | boolean |
| `taskId` | No | string |

Mode selector: `none`, default `default`
- `default`, prompt optional, max images 1, max videos 1

#### `keling-action-imitation`

| Field | Required | Contract Type |
| --- | --- | --- |
| `model` | No | enum(K26 \| V), default "K26" |
| `imageUrl` | No | string |
| `imageUrls` | No | string[] (maxItems 7) |
| `videoUrl` | No | string |
| `videoMediaId` | No | string |
| `mode` | No | enum(std \| pro) |
| `keepOriginalSound` | No | enum(yes \| no) |
| `characterOrientation` | No | enum(image \| video) |
| `aspectRatio` | No | enum(16:9 \| 9:16 \| 4:3 \| 3:4 \| 1:1) |
| `resolution` | No | enum(540p \| 720p \| 1080p) |
| `removeAudio` | No | boolean |
| `callbackUrl` | No | string (url) |
| `_skipQueue` | No | boolean |
| `taskId` | No | string |

Mode selector: `model`, default `K26`
- `K26`, max images 1, max videos 1
- `V`, prompt optional, max images 7, max videos 1

#### `veo3`

| Field | Required | Contract Type |
| --- | --- | --- |
| `mode` | No | enum(text_to_video \| image_to_video), default "text_to_video" |
| `generationMode` | No | enum(text \| reference \| headtail), default "text" |
| `aspect_ratio` | No | enum(16:9 \| 9:16), default "16:9" |
| `seed` | No | number (min -1, max 18446744073709552000), default -1 |
| `imageUrls` | No | string[] |
| `numberOfVideos` | No | number |
| `durationSeconds` | No | number |
| `resolution` | No | enum(720p \| 1080p) |
| `fps` | No | number |
| `negativePrompt` | No | string |
| `personGeneration` | No | enum(allow_all), default "allow_all" |
| `enhancePrompt` | No | boolean |
| `generateAudio` | No | boolean |
| `_skipQueue` | No | boolean |
| `taskId` | No | string |

Mode selector: `generationMode`, default `headtail`
- `reference`, max images 3, min images 1
- `headtail`, max images 2, min images 1, resolution 720p/1080p
- `text`, max images 0

#### `tencent-veo3`

| Field | Required | Contract Type |
| --- | --- | --- |
| `modelName` | No | string |
| `modelVersion` | No | string |
| `resolution` | No | string |
| `aspectRatio` | No | string |
| `logoAdd` | No | number (int) \| enum(0 \| 1 \| auto) |
| `enableAudio` | No | boolean \| enum(true \| false \| auto) |
| `offPeak` | No | boolean \| enum(true \| false \| auto) |
| `referenceTypes` | No | string |
| `sceneType` | No | string |
| `prompt` | No | string |
| `negativePrompt` | No | string |
| `enhancePrompt` | No | boolean |
| `imageUrl` | No | string |
| `lastImageUrl` | No | string |
| `imageUrls` | No | string[] |
| `imageInfos` | No | { imageUrl: string; referenceType?: string }[] |
| `duration` | No | number (int) |
| `additionalParameters` | No | string |
| `extraParameters` | No | Record<string, any> |
| `_skipQueue` | No | boolean |
| `taskId` | No | string |
| `generationMode` | No | enum(text \| image \| reference \| headtail) |

Mode selector: `generationMode`, default `headtail`
- `text`, max images 0
- `reference`, max images 3, min images 1
- `headtail`, max images 2, min images 1

#### `seedance-video-2-0`

| Field | Required | Contract Type |
| --- | --- | --- |
| `generationMode` | No | enum(text \| first_frame \| headtail \| multimodal), default "text" |
| `resolution` | No | enum(480p \| 720p), default "720p" |
| `ratio` | No | enum(16:9 \| 4:3 \| 1:1 \| 3:4 \| 9:16 \| 21:9 \| adaptive), default "adaptive" |
| `duration` | No | number (int), default 5 |
| `generate_audio` | No | boolean, default true |
| `watermark` | No | boolean, default false |
| `imageUrls` | No | string[] (maxItems 9) |
| `videoUrls` | No | string[] (maxItems 3) |
| `audioUrls` | No | string[] (maxItems 3) |
| `_skipQueue` | No | boolean |
| `taskId` | No | string |

Mode selector: `generationMode`, default `text`
- `text`, max images 0, max videos 0, max audios 0
- `headtail`, prompt optional, max images 2, min images 1,
  max videos 0, max audios 0
- `multimodal`, prompt optional, max images 9, max videos 3,
  max audios 3

#### `seedance-video-2-0-fast`

| Field | Required | Contract Type |
| --- | --- | --- |
| `generationMode` | No | enum(text \| first_frame \| headtail \| multimodal), default "text" |
| `resolution` | No | enum(480p \| 720p), default "720p" |
| `ratio` | No | enum(16:9 \| 4:3 \| 1:1 \| 3:4 \| 9:16 \| 21:9 \| adaptive), default "adaptive" |
| `duration` | No | number (int), default 5 |
| `generate_audio` | No | boolean, default true |
| `watermark` | No | boolean, default false |
| `imageUrls` | No | string[] (maxItems 9) |
| `videoUrls` | No | string[] (maxItems 3) |
| `audioUrls` | No | string[] (maxItems 3) |
| `_skipQueue` | No | boolean |
| `taskId` | No | string |

Mode selector: `generationMode`, default `text`
- `text`, max images 0, max videos 0, max audios 0
- `headtail`, prompt optional, max images 2, min images 1,
  max videos 0, max audios 0
- `multimodal`, prompt optional, max images 9, max videos 3,
  max audios 3

#### `seedance-video-1-5`

| Field | Required | Contract Type |
| --- | --- | --- |
| `mode` | No | enum(text_to_video \| image_to_video), default "text_to_video" |
| `resolution` | No | enum(480p \| 720p \| 1080p), default "720p" |
| `ratio` | No | enum(21:9 \| 16:9 \| 4:3 \| 1:1 \| 3:4 \| 9:16 \| 9:21 \| keep_ratio \| adaptive), default "16:9" |
| `duration` | No | enum(4 \| 5 \| 6 \| 7 \| 8 \| 9 \| 10 \| 11 \| 12), default "5" |
| `framepersecond` | No | enum(16 \| 24), default "24" |
| `watermark` | No | boolean, default false |
| `seed` | No | number (min -1, max 4294967295), default -1 |
| `camerafixed` | No | boolean, default false |
| `imageUrls` | No | string[] |
| `_skipQueue` | No | boolean |
| `taskId` | No | string |

#### `seedance-video-1-0`

| Field | Required | Contract Type |
| --- | --- | --- |
| `mode` | No | enum(text_to_video \| image_to_video), default "text_to_video" |
| `resolution` | No | enum(480p \| 720p \| 1080p), default "720p" |
| `ratio` | No | enum(21:9 \| 16:9 \| 4:3 \| 1:1 \| 3:4 \| 9:16 \| 9:21 \| keep_ratio \| adaptive), default "16:9" |
| `duration` | No | enum(2 \| 3 \| 4 \| 5 \| 6 \| 7 \| 8 \| 9 \| 10 \| 11 \| 12), default "5" |
| `framepersecond` | No | enum(16 \| 24), default "24" |
| `watermark` | No | boolean, default false |
| `seed` | No | number (min -1, max 4294967295), default -1 |
| `camerafixed` | No | boolean, default false |
| `imageUrls` | No | string[] |
| `_skipQueue` | No | boolean |
| `taskId` | No | string |

#### `keling-video`

| Field | Required | Contract Type |
| --- | --- | --- |
| `model` | No | enum(K10 \| K16 \| K20), default "K20" |
| `negativePrompt` | No | string |
| `cfgScale` | No | number (min 0, max 1), default 0.5 |
| `duration` | No | literal(5) \| literal(10), default 5 |
| `imageUrls` | No | string[] |
| `_skipQueue` | No | boolean |
| `taskId` | No | string |

#### `keling-ko1`

| Field | Required | Contract Type |
| --- | --- | --- |
| `generationMode` | No | enum(reference \| headtail \| video), default "reference" |
| `mode` | No | enum(pro \| std), default "pro" |
| `aspectRatio` | No | enum(16:9 \| 9:16 \| 1:1), default "16:9" |
| `duration` | No | literal(3) \| literal(4) \| literal(5) \| literal(6) \| literal(7) \| literal(8) \| literal(9) \| literal(10), default 5 |
| `imageUrls` | No | string[] (maxItems 7) |
| `refImages` | No | { imageUrl: string }[] (maxItems 7) |
| `headtailImages` | No | { headImage: { imageUrl: string }; tailImage?: { imageUrl: string } } |
| `elements` | No | { elementId: string }[] |
| `elementIds` | No | string[] |
| `videoUrl` | No | string |
| `videoUrls` | No | string[] (maxItems 1) |
| `videoList` | No | { videoUrl: string; type?: enum(base \| feature); keepSound?: enum(yes \| no) }[] (maxItems 1) |
| `videoType` | No | enum(base \| feature) |
| `keepSound` | No | enum(yes \| no) |
| `_skipQueue` | No | boolean |
| `taskId` | No | string |

Mode selector: `generationMode`, default `reference`,
reference-video mode `video`
- `reference`, max images 7, min images 0
- `headtail`, max images 2, min images 1, duration 5/10
- `video`, max images 4, min images 0, max videos 1
  field `videoUpload`, key `videoUrl`, required, maxCount 1,
  accepts reference video, visibleIn creation

#### `midjourney-video`

| Field | Required | Contract Type |
| --- | --- | --- |
| `imageUrl` | No | string |
| `manual` | No | enum(low \| high), default "low" |
| `imageUrls` | No | string[] |
| `_skipQueue` | No | boolean |
| `taskId` | No | string |

#### `vidu-video`

| Field | Required | Contract Type |
| --- | --- | --- |
| `model` | No | enum(VQ2 \| VQ2P), default "VQ2" |
| `generationMode` | No | enum(text \| reference \| headtail), default "text" |
| `duration` | No | literal(1) \| literal(2) \| literal(3) \| literal(4) \| literal(5) \| literal(6) \| literal(7) \| literal(8), default 4 |
| `resolution` | No | enum(360p \| 540p \| 720p \| 1080p), default "720p" |
| `aspectRatio` | No | enum(16:9 \| 9:16 \| 3:4 \| 4:3 \| 1:1), default "16:9" |
| `style` | No | enum(general \| anime), default "general" |
| `movementAmplitude` | No | enum(auto \| small \| medium \| large), default "auto" |
| `bgm` | No | boolean, default false |
| `seed` | No | number (int, min -1, max 2147483647) |
| `imageUrls` | No | string[] (maxItems 7) |
| `_skipQueue` | No | boolean |
| `taskId` | No | string |

Mode selector: `generationMode`, default `headtail`
- `reference`, max images 7, min images 1
- `headtail`, max images 2, min images 1, duration 2/3/4/5/6/7/8,
  resolution 720p/1080p
- `text`, max images 0

#### `hailuo-video`

| Field | Required | Contract Type |
| --- | --- | --- |
| `useSubjectReference` | No | boolean |
| `imageUrls` | No | string[] |
| `_skipQueue` | No | boolean |
| `taskId` | No | string |
| `duration` | No | number |
| `resolution` | No | string |

#### `sora2-video`

| Field | Required | Contract Type |
| --- | --- | --- |
| `generationMode` | No | enum(video \| character), default "video" |
| `model` | No | enum(sora-2 \| sora-2-pro), default "sora-2" |
| `orientation` | No | enum(landscape \| portrait), default "landscape" |
| `duration` | No | enum(10 \| 15 \| 25), default "10" |
| `video_title` | No | string |
| `characterUrl` | No | string |
| `characterTimestamps` | No | string |
| `imageUrls` | No | string[] |
| `_skipQueue` | No | boolean |
| `taskId` | No | string |

Mode selector: `generationMode`, default `video`,
reference-video mode `character`
- `video`, max images 5
- `character`, prompt optional, max images 0, max videos 0
  field `videoUpload`, key `characterUrl`, required, maxCount 1,
  accepts reference video, visibleIn creation
  field `timeRange`, required, range
  characterTimestampStart~characterTimestampEnd

#### `sora2-video-by-azure`

| Field | Required | Contract Type |
| --- | --- | --- |
| `model` | No | enum(sora-2 \| sora-2-pro), default "sora-2" |
| `size` | No | enum(1280x720 \| 720x1280 \| 1024x1792 \| 1792x1024), default "1280x720" |
| `duration` | No | enum(4 \| 8 \| 12), default "4" |
| `imageUrls` | No | string[] |
| `_skipQueue` | No | boolean |
| `taskId` | No | string |

#### `wanxiang-video`

| Field | Required | Contract Type |
| --- | --- | --- |
| `model` | No | enum(wan2.5-i2v-preview \| wan2.5-t2v-preview), default "wan2.5-i2v-preview" |
| `negativePrompt` | No | string |
| `no` | No | string |
| `audioUrl` | No | string |
| `audio` | No | boolean, default true |
| `imageUrl` | No | string |
| `imageUrls` | No | string[] |
| `resolution` | No | enum(480p \| 720p \| 1080p), default "1080p" |
| `_skipQueue` | No | boolean |
| `taskId` | No | string |
| `seed` | No | number |
| `duration` | No | number (min 5, max 10) |
| `watermark` | No | boolean, default false |
| `prompt_extend` | No | boolean, default true |
| `aspect_ratio` | No | enum(16:9 \| 9:16 \| 1:1 \| 4:3 \| 3:4), default "16:9" |
| `first_frame_image` | No | string |
| `last_frame_image` | No | string |
| `template` | No | string |

#### `wanxiang-video-2-6`

| Field | Required | Contract Type |
| --- | --- | --- |
| `model` | No | enum(wan2.6-i2v \| wan2.6-t2v \| wan2.6-r2v), default "wan2.6-i2v" |
| `generationMode` | No | enum(video \| character), default "video" |
| `negativePrompt` | No | string |
| `no` | No | string |
| `audioUrl` | No | string |
| `audio` | No | boolean, default true |
| `imageUrl` | No | string |
| `imageUrls` | No | string[] |
| `resolution` | No | enum(480p \| 720p \| 1080p), default "1080p" |
| `_skipQueue` | No | boolean |
| `taskId` | No | string |
| `seed` | No | number |
| `duration` | No | number (min 5, max 15) |
| `watermark` | No | boolean, default false |
| `prompt_extend` | No | boolean, default true |
| `aspect_ratio` | No | enum(16:9 \| 9:16 \| 1:1 \| 4:3 \| 3:4), default "16:9" |
| `first_frame_image` | No | string |
| `last_frame_image` | No | string |
| `template` | No | string |
| `shot_type` | No | enum(multi \| single), default "multi" |
| `reference_video_urls` | No | string[] (maxItems 3) |

Mode selector: `generationMode`, default `video`,
reference-video mode `character`
- `video`, max audios 1
- `character`, max images 0, max videos 1, max audios 1
  field `videoUpload`, key `reference_video_urls`, required,
  maxCount 3, accepts reference video

#### `volcengine-visual`

| Field | Required | Contract Type |
| --- | --- | --- |
| `imageUrl` | Yes | string |
| `videoUrl` | Yes | string |
| `_skipQueue` | No | boolean |
| `taskId` | No | string |

Mode selector: `none`, default `default`
- `default`, prompt optional, max images 1, max videos 1

#### `youchuan-video`

| Field | Required | Contract Type |
| --- | --- | --- |
| `imageUrl` | No | string |
| `imageUrls` | No | string[] |
| `manual` | No | enum(low \| high), default "low" |
| `videoType` | No | enum(0 \| 1) |
| `callback` | No | string |
| `_skipQueue` | No | boolean |
| `taskId` | No | string |

#### `volcengine-visual-digital-human`

| Field | Required | Contract Type |
| --- | --- | --- |
| `prompt` | No | string |
| `imageUrl` | Yes | string |
| `audioUrl` | Yes | string |
| `seed` | No | number |
| `peFastMode` | No | boolean |
| `_skipQueue` | No | boolean |
| `taskId` | No | string |

Mode selector: `none`, default `default`
- `default`, prompt optional, max images 1, max audios 1

#### `hunyuan`

| Field | Required | Contract Type |
| --- | --- | --- |
| `modelName` | No | string |
| `modelVersion` | No | string |
| `resolution` | No | string |
| `aspectRatio` | No | string |
| `logoAdd` | No | number (int) \| enum(0 \| 1 \| auto) |
| `enableAudio` | No | boolean \| enum(true \| false \| auto) |
| `offPeak` | No | boolean \| enum(true \| false \| auto) |
| `referenceTypes` | No | string |
| `sceneType` | No | string |
| `prompt` | No | string |
| `negativePrompt` | No | string |
| `enhancePrompt` | No | boolean |
| `imageUrl` | No | string |
| `lastImageUrl` | No | string |
| `imageUrls` | No | string[] |
| `imageInfos` | No | { imageUrl: string; referenceType?: string }[] |
| `duration` | No | number (int) |
| `additionalParameters` | No | string |
| `extraParameters` | No | Record<string, any> |
| `_skipQueue` | No | boolean |
| `taskId` | No | string |

Mode selector: `none`, default `default`
- `default`, max images 7

### Audio Providers

#### `volcengine-tts`

| Field | Required | Contract Type |
| --- | --- | --- |
| `req_params` | Yes | { text?: string; ssml?: string; speaker: string; audio_params: { format?: enum(mp3 \| wav \| pcm \| ogg_opus \| aac \| flac); sample_rate?: number; emotion?: string; speech_rate?: number; loudness_rate?: number; pitch?: number } } |
| `additions` | No | { disable_markdown_filter?: boolean; disable_emoji_filter?: boolean } |
| `referenceAudioUrls` | No | string[] |
| `_skipQueue` | No | boolean |
| `taskId` | No | string |

#### `noiz-tts`

| Field | Required | Contract Type |
| --- | --- | --- |
| `voiceId` | No | string |
| `referenceAudioUrls` | No | string[] |
| `outputFormat` | No | enum(mp3 \| wav) |
| `qualityPreset` | No | number (int, min 1, max 5) |
| `speed` | No | number (min 0.5, max 2) |
| `duration` | No | number (min 0) |
| `targetLang` | No | string |
| `similarityEnh` | No | boolean |
| `emotionJson` | No | string |
| `saveVoice` | No | boolean |
| `_skipQueue` | No | boolean |
| `taskId` | No | string |
