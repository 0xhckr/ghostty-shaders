# Ghostty Shaders

<p align="center">
  <img src="./assets/banner.svg" width="100%">
</p>

---

### A collection of GLSL fragment shaders optimized for [Ghostty](https://ghostty.org/) terminal v1.3.0+.

These shaders have been written to enforce GLSL type safety, resolve `iChannel0` initialization races, and play nicely with strict Mesa drivers and Ghostty engine changes without tanking your framerate.
One folder contains the works this project was [forked](https://github.com/0xhckr/ghostty-shaders) from. I just want a place to curate shaders better, and a place for new and consistent contributors with well-performing shaders to have their own "collection," if you will, represented in the form of a directory in this repo. 

A unique collection curated by individuals with talent to show their stuff to the community. Nothing Ghostty ricing is off-limits. There will be more structure to follow along with as I develop this further, so there will be no confusion about what to do if you wish to make a contribution.
>For the time being keep all *questions* or *contribution ideas* will be treated as *issues* untill the project matures.  

Rules off the bat: 
No AI. 
Contributions made with LLMs, or with LLMs listed as contributors, will be rejected.

>The original maintainers do not share this policy, so you may find AI contributions in /ghostty-shaders-original.

For now, enjoy what's displayed here!!!
And thank you for checking out the repo!
While it's still a work in progress, I hope you enjoy and look forward to watching the project grow.

Below are **Installation** instructions.(will always work on the main branch, even as the project gets more complex.)

---
. Tree view

```
~/.config/
│
└── ghostty/
    │
    ├── config
    │
    └── GSIM/
        │
        ├── README.md
        ├── assets/
        │   ├── banner.svg
        │   ├── ghost.svg
        │   └── logo.svg
        │
        └── shaders/
            ├── Lizard-Originals/
            │   ├── shader1.glsl
            │   └── shader2.glsl
            │
            ├── ghostty-originals/
            │   ├── shader1.glsl
            │   └── shader2.glsl
            │
            └── ContributorName/
                ├── shader1.glsl
                └── shader2.glsl
```
---

## Installation

Clone the repository:

```bash
git clone https://github.com/GrandBIRDLizard/GSIM.git
```
Make Ghostty's new GSIM config dir via:

```bash
mkdir -p ~/.config/ghostty/GSIM/Active
```

Copy a collection:

```bash
cp ~/GSIM/shaders/Lizard-Originals/*.glsl \
   ~/.config/ghostty/GSIM/shaders/Active/
```

Or a single shader:

```bash
cp ~/GSIM/shaders/Lizard-Originals/crt.glsl \
   ~/.config/ghostty/GSIM/shaders/Active/
```
---

Where ever you put it, point Ghostty at it:

```ini
custom-shader = ~/.config/ghostty/GSIM/shaders/Active/crt.glsl
```

## **Config Tooling Coming Soon**

---

## Troubleshooting:

### "Unknown Field" Errors:
If you see `unknown field` errors in your logs, you likely pasted GLSL code directly into your Ghostty `config`.

**The fix:** 1. Ensure all GLSL code is in a separate `.glsl` file.
2. In your `config`, only use the `custom-shader = path/to/shader.glsl` directive.

---

### Performance & Latency:
To maintain a steady 60/120 FPS on high-refresh displays:
* Use `custom-shader-animation = true` to pause rendering when the window is hidden.
* Keep the math inside `mainImage` as lean as possible—avoid complex loops

## Progress 
anything inside ghostty-shaders is not currently optimized, I will continue to pull new updates in from the maintainers but I will not make any direct progress with the project. 
repo is a work in progress, I've been tooling with in my spare time will tag a pre-release with tags soon. 
when I feel I've made significant progress or I've come to a final direction for project. 

## Lizard-originals  
where my Independant work will reside, 
and each contributer who would like to contribute and have a "slot" can do so by continual contribution and or helpful solutions/ideas/discussion.
slot in this sense is a directory in the repo to hold a portfolio of work to show off. Distinct of one off contributions. 
**I will make a spot or system for such one off works when I get the build and configuration stable.** 

---
# site not implemented will be available when project ships Pictures will be desplayed in README.md Gif's will be on the website

## 📖 The Interactive site:
Don't just read the code see it in action. Visit the [Ghostty Shader site](https://my-site-link.com) 
to preview every shader with high-res recordings and one-click installation.
