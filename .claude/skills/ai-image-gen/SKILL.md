---
name: ai-image-gen
description: "Generate, edit, and post-process images using AI models (Google Gemini Imagen). Text-to-image generation, background removal, cropping, watermark removal, vectorization. Actions: generate, create, design, make, draw, render image/icon/logo/illustration/graphic. Triggers: image, icon, logo, illustration, graphic, picture, photo, diagram, banner, favicon, avatar, badge, chart."
---

# AI Image Generation Skill

Generate images with Google Gemini and post-process them (crop, remove background, vectorize).

## Prerequisites

Install dependencies (once):
```bash
pip install google-generativeai pillow rembg 2>/dev/null || pip install google-generativeai pillow
```

Set API key:
```bash
export GEMINI_API_KEY="your-api-key"
```

## When to Use

Use this skill when the user asks to:
- Generate, create, or design any image, icon, logo, illustration
- Replace an existing image with an AI-generated one
- Remove background from an image
- Crop or trim an image (e.g., remove watermarks)
- Convert a raster image to vector SVG

## How to Use

### Step 1: Generate Image

```bash
python3 .claude/skills/ai-image-gen/scripts/generate.py "YOUR PROMPT HERE" --output /path/to/output.png
```

**Prompt Tips:**
- Be specific: "modern flat-design rocket icon, dark background, blue accent, 3D render" beats "rocket"
- Specify style: "minimalist", "3D render", "flat design", "photorealistic", "vector style"
- Specify context: "for dark mode UI", "transparent background", "white background"
- Specify dimensions context: "square icon 512x512", "wide banner"

### Step 2: Post-Process (optional)

```bash
# Remove background
python3 .claude/skills/ai-image-gen/scripts/process.py INPUT.png --remove-bg --output OUTPUT.png

# Crop (remove watermark from bottom-right)
python3 .claude/skills/ai-image-gen/scripts/process.py INPUT.png --crop-bottom 50 --output OUTPUT.png

# Crop to custom bounds (left, top, right, bottom pixels)
python3 .claude/skills/ai-image-gen/scripts/process.py INPUT.png --crop 0 0 900 900 --output OUTPUT.png

# Vectorize to SVG
python3 .claude/skills/ai-image-gen/scripts/process.py INPUT.png --vectorize --output OUTPUT.svg

# Chain operations: remove bg + vectorize
python3 .claude/skills/ai-image-gen/scripts/process.py INPUT.png --remove-bg --vectorize --output OUTPUT.svg

# Resize
python3 .claude/skills/ai-image-gen/scripts/process.py INPUT.png --resize 256x256 --output OUTPUT.png
```

### Step 3: Use the Generated Image

After generation, read/view the image to verify quality. If not satisfactory, re-generate with a refined prompt. Replace the target file when satisfied.

## Workflow for Replacing App Assets

1. **Identify** the current image file and its usage context
2. **Analyze** the current image (read it to understand style, colors, composition)
3. **Generate** a replacement with a detailed prompt matching the app's visual style
4. **Post-process** as needed (crop watermarks, remove background, resize)
5. **Replace** the file at the original path
6. **Verify** by reading the new file

## Models

| Model | Best For | Notes |
|-------|----------|-------|
| gemini-2.0-flash-exp | General images, illustrations | Default, fast, good quality |
| gemini-2.5-flash-preview-05-20 | High quality | Newer, better quality |

## Output Locations

- Default: `./.ai-gen-output/` in current directory
- Custom: Use `--output /path/to/file.png`
- Temp: Use `--output /tmp/gen-image.png` for throwaway

## Error Handling

- If GEMINI_API_KEY is not set, the script will error with instructions
- If generation fails, try simplifying the prompt or using fewer details
- If post-processing fails, ensure pillow/rembg is installed
