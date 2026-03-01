# Discourse Swiper Cooked - Extended Version

This is a modified version of the original discourse-swiper theme component that adds support for iframe embeds and full cooked content blocks in swiper slides.

## New Features

### 1. iFrame Support
You can now include iframe embeds (like YouTube videos, maps, or other embedded content) directly in swiper slides.

**Usage:**
```html
<div class="swiper-wrap">
  <iframe src="https://www.youtube.com/embed/VIDEO_ID" width="560" height="315"></iframe>
  <iframe src="https://www.google.com/maps/embed?pb=..." width="600" height="450"></iframe>
</div>
```

The iframes will automatically be detected and rendered as separate slides with proper styling.

### 2. Cooked Content Blocks
You can include full Discourse cooked content (formatted posts with markdown, images, links, etc.) as slides.

**Usage:**
Wrap your content in a div with class `cooked-content`, `swiper-cooked-slide`, or add the attribute `data-swiper-cooked`:

```html
<div class="swiper-wrap">
  <div class="cooked-content">
    <h2>Slide Title</h2>
    <p>This is a full content slide with <strong>markdown</strong> support.</p>
    <img src="/uploads/default/image.png" alt="Image" />
    <ul>
      <li>List item 1</li>
      <li>List item 2</li>
    </ul>
  </div>
  
  <div class="swiper-cooked-slide">
    <h3>Another Content Slide</h3>
    <p>More content here...</p>
  </div>
</div>
```

### 3. Caption Support
Both iframe and cooked content slides support optional captions. Any `<p>` tags following the media element will be captured as captions.

```html
<div class="swiper-wrap">
  <iframe src="https://example.com/embed"></iframe>
  <p>This is a caption for the iframe</p>
  
  <div class="cooked-content">
    <h2>Content</h2>
  </div>
  <p>This is a caption for the cooked content</p>
</div>
```

## Technical Changes

Three files were modified to add this functionality:

### 1. `javascripts/discourse/lib/media-element-parser.js`
- Added `isIframe()` method to detect iframe elements
- Added `isCookedContent()` method to detect cooked content blocks
- Added `createCookedThumbnail()` method to generate thumbnails for cooked content
- Updated `run()` method to process iframe and cooked content elements
- Updated `extractFollowingCaption()` to handle new content types

### 2. `javascripts/discourse/components/swiper-inline.gjs`
- Added template rendering for iframe slides with `.swiper-iframe-wrapper`
- Added template rendering for cooked content slides with `.swiper-cooked-wrapper`
- Both new slide types support captions via `swiper-slide-content`

### 3. `stylesheets/swiper.scss`
- Added `.swiper-iframe-wrapper` styles for iframe slides
  - Centered layout with responsive sizing
  - Max height of 600px (400px on mobile)
  - Clean styling with rounded corners
  
- Added `.swiper-cooked-wrapper` styles for cooked content slides
  - Scrollable container with proper padding
  - Inherits Discourse theme variables for colors
  - Full typography support (headings, paragraphs, lists, blockquotes)
  - Code block styling
  - Table support
  - Responsive font sizing
  - Maintains lightbox functionality for images
  
- Added `.cooked-thumbnail` styles for thumbnail navigation
  - Text preview with ellipsis for overflow
  - Centered layout with theme-aware colors
  
- Added `.swiper-slide-content` styles for captions
  - Positioned at bottom of slide
  - Semi-transparent dark background
  - White text for readability

## Styling Customization

The styles use Discourse CSS variables for theme compatibility:
- `--primary` - Main text color
- `--secondary` - Background color
- `--tertiary` - Link color
- `--primary-low` - Light borders
- `--primary-very-low` - Subtle backgrounds
- `--primary-medium` - Muted text

You can customize these in your Discourse theme settings or override specific styles:

```scss
.swiper-cooked-wrapper {
  .cooked-content {
    font-size: 1.1em; // Larger text
    max-width: 900px; // Wider content area
  }
}

.swiper-iframe-wrapper iframe {
  max-height: 800px; // Taller iframes
}
```

## Compatibility

This version maintains full backward compatibility with the original discourse-swiper component. All existing image galleries and configurations will continue to work as before.

## Usage Notes

1. **Mixed Content**: You can mix images, iframes, and cooked content in the same swiper
2. **Thumbnails**: Cooked content automatically generates text-based thumbnails if no image is found
3. **Scrolling**: Cooked content slides are scrollable if content exceeds slide height
4. **Responsive**: All new slide types are fully responsive with mobile optimizations
5. **Lightbox**: Images within cooked content slides maintain lightbox functionality

## Example: Complete Swiper with Mixed Content

```html
[wrap=swiper config="{navigation: {enabled: true}, pagination: {enabled: true}}"]

<img src="/uploads/image1.jpg" alt="Photo 1" />
<p>Photo caption</p>

<div class="cooked-content">
  <h2>Welcome Slide</h2>
  <p>This is a text-based slide with full markdown support.</p>
  <ul>
    <li>Feature 1</li>
    <li>Feature 2</li>
  </ul>
</div>

<iframe src="https://www.youtube.com/embed/dQw4w9WgXcQ" width="560" height="315"></iframe>
<p>Video tutorial</p>

<img src="/uploads/image2.jpg" alt="Photo 2" />

<div class="cooked-content">
  <h2>More Information</h2>
  <p>Another content slide...</p>
  <img src="/uploads/diagram.png" alt="Diagram" />
</div>

[/wrap]
```

## Contributing

This is a fork of the original discourse-swiper component. For issues specific to iframe and cooked content support, please file issues in this repository. For general swiper functionality, refer to the original project.

## Original Component

Based on: [discourse-swiper](https://github.com/discourse/discourse-swiper)

## License

MIT License (same as original)
