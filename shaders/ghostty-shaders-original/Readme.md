## Installation

Clone the repository:

```sh
git clone --depth 1 https://github.com/hackr-sh/ghostty-shaders
cd ghostty-shaders
```

Copy your preferred shader file to the Ghostty config directory:

```sh
cp <your-choice>.glsl ~/.config/ghostty/shaders/shader.glsl
```

Add the following line to your `~/.config/ghostty/config` file to enable the custom shader:

```ini
custom-shader = ~/.config/ghostty/shaders/shader.glsl
```
