---
name: ui-layer-split
description: >-
  Split an image into transparent RGBA layers using the Qwen Image Layered model
  running locally at http://192.168.1.53:8000. Use this skill whenever the user
  wants to: separate an image into layers, remove or replace background,
  decompose a photo into foreground and background, create transparent PNG
  cutouts, split a banner or illustration into editable parts, prepare layers
  for motion graphics or 2.5D animation, or do anything involving image layer
  separation or segmentation. Trigger even if the user just says something like
  "split this image", "separate the layers", "cut out the background", or
  "give me the layers for this photo".
---

# Layer Split

Splits an image into multiple transparent RGBA layers using the Qwen Image Layered model. The model understands scene structure and automatically decides how to separate objects — you just describe the image naturally.

**Resolution policy:** The model supports max `res=1024`. For images larger than 1024px, always run at `res=1024` then upscale the alpha masks back to the original resolution in post-processing (Step 5). This preserves original pixel quality while using the best available mask precision.

## Service

API endpoint: `http://192.168.1.53:8000/layer-segmentation/`
Service directory: `/home/priter/qwen-layerd/`

## Parameters

| Param | Default | Notes |
|---|---|---|
| `num_layers` | 2 | Number of output layers (2–8). Formula: latent_length = layers × 4 + 1 |
| `resolution` | 1024 | Resolution: `640` (fast, ~60s) or `1024` (quality, ~170s). Use 1024 by default. |
| `prompt` | auto | Describe the scene naturally, e.g. "A cat on a wooden table". Don't describe layers. |
| `use_gguf` | true | GGUF Q4_K_M model (~13 GB VRAM). Set false for FP8 safetensors (~20 GB VRAM) |

**Shift rule** (set automatically): `res=640` → shift 1.0, `res=1024` → shift 3.0

**Layer count guide:**
- 2 layers → subject + background
- 3 layers → foreground prop + subject + background
- 5 layers → full decomposition with shadows/effects
- 8 layers → maximum detail (vector art, motion graphics)

## Steps

### 1. Parse user intent

Extract from the user's message:
- Image path (required)
- Original image resolution — read it first with `.NET` or `python -c "from PIL import Image..."` before proceeding
- Desired number of layers (default 5; if they say "just background removal" use 2, "lots of detail" suggest 5–8)
- Scene prompt (derive from image filename or ask if unclear)

### 2. Check service

Use `curl.exe` (not `curl`) on Windows PowerShell:

```powershell
curl.exe -s --max-time 5 http://192.168.1.53:8000/docs -o NUL -w "%{http_code}"
```

If output is `200` the service is UP. If DOWN, start it (takes ~4 seconds) via SSH or notify the user.

### 3. Call the API

On Windows PowerShell always use `curl.exe` (the built-in `curl` alias maps to `Invoke-WebRequest` and will fail):

```powershell
curl.exe -X POST http://192.168.1.53:8000/layer-segmentation/ `
  -F "image_file=@IMAGE_PATH" `
  -F "prompt=PROMPT" `
  -F "num_layers=N" `
  -F "resolution=1024" `
  -F "use_gguf=true" `
  -o "OUTPUT_ZIP" `
  --max-time 660 `
  -w "\nHTTP %{http_code} in %{time_total}s"
```

Where `OUTPUT_ZIP` = a temp file in the same directory as the image, named `<basename>_layers_tmp.zip`. This file will be deleted after extraction.

If HTTP status is not 200, print the response body so the user can see the error.

### 4. Extract ZIP and delete it

```powershell
$outputDir = "LAYERS_DIR"   # <basename>_layers1024
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
Expand-Archive -Path "OUTPUT_ZIP" -DestinationPath $outputDir -Force
Remove-Item "OUTPUT_ZIP" -Force
Get-ChildItem $outputDir | Select-Object Name, @{N='Size';E={[math]::Round($_.Length/1KB,1)}} | Format-Table
```

### 5. Restore original resolution (always run this step)

The model outputs at 1024px. Use the bundled script to upscale alpha masks back to original size and composite with the original RGB pixels. The script auto-detects whether upscaling is needed.

```powershell
python "scripts/restore_resolution.py" "ORIGINAL_IMAGE_PATH" "LAYERS_DIR" "FINAL_OUTPUT_DIR"
Remove-Item "LAYERS_DIR" -Recurse -Force
```

- `ORIGINAL_IMAGE_PATH` — the source image (e.g. `art-ui/foo.png`)
- `LAYERS_DIR` — extracted layers folder from Step 4 (e.g. `art-ui/foo_layers1024`), deleted after restore
- `FINAL_OUTPUT_DIR` — destination for full-resolution layers (e.g. `art-ui/foo_layers_final`)

### 6. Report results

Report back:
- Original resolution vs. output resolution
- Number of layers extracted
- Full path of the **final** output directory (the `_layers_final` folder after step 5)
- Each PNG filename (`reference.png` = original reference frame, `layer_1.png` onward = separated layers)
- Time taken
- Suggest next steps if relevant (e.g., "layer_1.png is likely the sky background, layer_5.png contains the foreground UI panel")
