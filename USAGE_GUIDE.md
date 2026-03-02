# Swiper Usage Guide - Working Solutions

## What Works Right Now

### ✅ iFrames (Fully Working)

```markdown
[wrap=swiper]
<iframe src="https://en.wikipedia.org/wiki/Article"></iframe>
<iframe src="https://www.youtube.com/embed/VIDEO_ID"></iframe>
[/wrap]
```

### ✅ Images with Captions (Fully Working)

```markdown
[wrap=swiper config="{navigation: {enabled: true}}"]
<img src="/uploads/image1.jpg" alt="Photo 1" />
<p>Caption for photo 1</p>

<img src="/uploads/image2.jpg" alt="Photo 2" />
<p>Caption for photo 2</p>
[/wrap]
```

### ✅ Mixed Content (Fully Working)

```markdown
[wrap=swiper config="{navigation: {enabled: true}, pagination: {enabled: true}}"]
<img src="/uploads/photo.jpg" />
<p>A beautiful photo</p>

<iframe src="https://www.youtube.com/embed/VIDEO_ID"></iframe>
<p>Watch this tutorial</p>

<img src="/uploads/another-photo.jpg" />
[/wrap]
```

## Why Text Content Slides Don't Work

Discourse strips custom `<div>` tags and classes for security. The error "HTML content omitted" means your HTML was sanitized.

## Workarounds for Text Content

### Option 1: Use Blockquotes

Update the parser to detect blockquotes as text slides.

### Option 2: Image + Long Caption

Use a minimal image with extensive caption text below it.

### Option 3: Create iFrame Slides

Create simple HTML pages and embed them as iframes.
