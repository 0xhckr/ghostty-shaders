# Ghostty Shaders

A collection of GLSL fragment shaders optimized for [Ghostty](https://ghostty.org/) terminal v1.3.0+. 

These shaders have been rewritten to enforce strict GLSL type safety, resolve `iChannel0` initialization races, and play nicely with strict Mesa drivers without tanking your framerate.

---

## Installation

Clone the repository:

```bash
git clone [ghostty-shaders](https://github.com/GrandBIRDLizard/ghostty-shaders)
cd ghostty-shaders
```
Copy your favorite shaders to `~/.config/shostty/shaders` via:

```bash
mkdir -p ~/.config/ghostty/shaders
cp shader.glsl ~/.config/ghostty/shaders/
```
or move all of them at once with:

>assuming you've cloned the repo in your home dir.

```bash
mkdir -p ~/.config/ghostty/shaders && mv ./*.glsl ~/.config/ghostty/shaders/
```
>then dispose or place the source tree wherever you'd like.

---

## Troubleshooting:

### "Unknown Field" Errors:
If you see `unknown field` errors in your logs, you likely pasted GLSL code directly into your Ghostty `config`.

**The fix:** 1. Ensure all GLSL code is in a separate `.glsl` file.
2. In your `config`, only use the `custom-shader = path/to/shader.glsl` directive.

---

### Performance & Latency:
To maintain a steady 120 FPS on high-refresh displays:
* Use `custom-shader-animation = true` to pause rendering when the window is hidden.
* Keep the math inside `mainImage` as lean as possible—avoid complex loops

---
# site not implemented will be available when project ships Pictures will be desplayed in README.md Gif's will be on the website
## 📖 The Interactive site:
Don't just read the code see it in action. Visit the [Ghostty Shader site](https://my-site-link.com) 
to preview every shader with high-res recordings and one-click installation.
