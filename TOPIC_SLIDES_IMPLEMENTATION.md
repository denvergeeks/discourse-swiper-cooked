# Topic-Based Slides Implementation Guide

This guide explains how to implement SwiperJS slideshows that fetch and display cooked content from existing Discourse topics, similar to the collections-navigator pattern.

## Overview

You want topic authors to be able to create slideshows using the `[wrap=swiper][/wrap]` BBCode that:
1. Fetch cooked content from specified topics
2. Display that content as slides in a swiper
3. Work inline in posts
4. Work in the PhotoSwipe lightbox overlay

## Architecture

### Components Needed

1. **Topic Fetcher Utility** (✅ Created: `javascripts/discourse/lib/topic-fetcher.js`)
   - Fetches topic content via Discourse API
   - Parses topic IDs from BBCode attributes
   - Returns cooked HTML and metadata

2. **Extended Media Parser** (⚠️ Needs update)
   - Detect `data-topics` attribute in wrap element
   - Create placeholder items for topic slides
   - Mark them for async content loading

3. **Swiper Component Enhancement** (⚠️ Needs update)
   - Handle `topics` config parameter
   - Fetch topic content asynchronously
   - Render cooked content in slides
   - Update when content loads

4. **Lightbox Integration** (⚠️ Needs implementation)
   - Register cooked content slides with PhotoSwipe
   - Create overlay-compatible elements
   - Handle navigation in lightbox mode

## Implementation Steps

### Step 1: Update BBCode Parser

Modify `javascripts/discourse/api-initializers/discourse-swiper.gjs` to pass through the `topics` attribute:

```javascript
function applySwiper(element, helper) {
  const isPreview = !helper?.model;
  const container = document.createElement("div");
  container.classList.add("swiper-wrap-container");

  for (const [key, value] of Object.entries(element.dataset)) {
    container.dataset[camelize(key)] = value;
  }

  // Parse topics attribute if present
  const topicIds = element.dataset.topics 
    ? TopicFetcher.parseTopicIds(element.dataset) 
    : null;

  helper.renderGlimmer(container, SwiperInline, {
    preview: isPreview,
    config: parseWrapParam({ ...element.dataset }),
    parsedData: MediaElementParser.run(element),
    topicIds: topicIds, // NEW
  });

  element.replaceWith(container);
}
```

### Step 2: Update Swiper Component

Modify `javascripts/discourse/components/swiper-inline.gjs` to handle topic fetching:

```javascript
import TopicFetcher from "../lib/topic-fetcher";

export default class SwiperInline extends Component {
  @service siteSettings;
  @service activeSwiperInEditor;
  @tracked topicSlides = [];
  @tracked isLoadingTopics = false;

  constructor() {
    super(...arguments);
    
    // If topics are specified, fetch them
    if (this.args.topicIds && this.args.topicIds.length > 0) {
      this.loadTopicSlides();
    }
  }

  async loadTopicSlides() {
    this.isLoadingTopics = true;
    
    try {
      const topics = await TopicFetcher.fetchMultipleTopics(this.args.topicIds);
      
      // Convert topics to slide items
      this.topicSlides = topics.map(topic => ({
        type: "topic-slide",
        topicId: topic.topicId,
        title: topic.title,
        cooked: topic.cooked,
        thumbnail: this.createTopicThumbnail(topic),
      }));
      
      // Reinitialize swiper with new slides
      if (this.mainSlider) {
        this.destroySwiper();
        this.initializeSwiper(this.swiperWrapElement);
      }
    } catch (error) {
      console.error("Error loading topic slides:", error);
    } finally {
      this.isLoadingTopics = false;
    }
  }

  createTopicThumbnail(topic) {
    // Create a thumbnail element from topic data
    const div = document.createElement("div");
    div.className = "topic-thumbnail";
    div.innerHTML = `
      <div class="topic-thumbnail-title">${topic.title}</div>
      ${topic.excerpt ? `<div class="topic-thumbnail-excerpt">${topic.excerpt}</div>` : ""}
    `;
    return div;
  }

  @cached
  get allSlides() {
    // Combine regular parsed data with topic slides
    const regular = this.args.data?.parsedData || [];
    return [...regular, ...this.topicSlides];
  }
  
  // ... rest of component
}
```

### Step 3: Update Template

In the `swiper-inline.gjs` template section, handle topic slides:

```handlebars
<template>
  <div class="swiper-wrap" ...>
    <div class="swiper main-slider">
      <div class="swiper-wrapper">
        {{#if this.isLoadingTopics}}
          <div class="swiper-slide loading-slide">
            <div class="loading-spinner"></div>
            <p>Loading topics...</p>
          </div>
        {{else}}
          {{#each this.allSlides as |data|}}
            <div class="swiper-slide">
              
              {{#if (eq data.type "topic-slide")}}
                {{! NEW: Topic slide rendering }}
                <div class="swiper-topic-slide">
                  <div class="topic-slide-header">
                    <h3>{{data.title}}</h3>
                  </div>
                  <div class="cooked-content topic-content">
                    {{htmlSafe data.cooked}}
                  </div>
                </div>
              
              {{else if (eq data.type "image")}}
                {{data.node}}
              
              {{else if (eq data.type "iframe")}}
                <div class="swiper-iframe-wrapper">
                  {{data.node}}
                </div>
              
              {{else if (eq data.type "textcontent")}}
                <div class="swiper-text-wrapper">
                  {{data.node}}
                </div>
              {{/if}}
              
            </div>
          {{/each}}
        {{/if}}
      </div>
      {{! navigation, pagination, etc. }}
    </div>
  </div>
</template>
```

### Step 4: Add CSS Styles

Add to `stylesheets/swiper.scss`:

```scss
// Topic slide styles
.swiper-topic-slide {
  width: 100%;
  height: 100%;
  overflow-y: auto;
  overflow-x: hidden;
  padding: 2rem;
  background: var(--secondary);
  
  .topic-slide-header {
    margin-bottom: 1.5rem;
    padding-bottom: 1rem;
    border-bottom: 2px solid var(--primary-low);
    
    h3 {
      margin: 0;
      color: var(--primary);
      font-size: 1.75em;
      font-weight: bold;
    }
  }
  
  .topic-content {
    color: var(--primary);
    font-size: 1em;
    line-height: 1.6;
    
    // Inherit Discourse cooked styles
    p, ul, ol, blockquote {
      margin-bottom: 1em;
    }
    
    h1, h2, h3, h4, h5, h6 {
      margin-top: 1.5em;
      margin-bottom: 0.75em;
      font-weight: bold;
    }
    
    img {
      max-width: 100%;
      height: auto;
      display: block;
      margin: 1em auto;
    }
    
    .lightbox-wrapper {
      pointer-events: auto;
      cursor: pointer;
    }
  }
}

// Topic thumbnail for navigation
.topic-thumbnail {
  background: var(--primary-very-low);
  padding: 0.75rem;
  border-radius: 4px;
  height: 100%;
  display: flex;
  flex-direction: column;
  justify-content: center;
  
  .topic-thumbnail-title {
    font-weight: bold;
    color: var(--primary);
    font-size: 0.9em;
    margin-bottom: 0.25rem;
    overflow: hidden;
    text-overflow: ellipsis;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
  }
  
  .topic-thumbnail-excerpt {
    font-size: 0.75em;
    color: var(--primary-medium);
    overflow: hidden;
    text-overflow: ellipsis;
    display: -webkit-box;
    -webkit-line-clamp: 3;
    -webkit-box-orient: vertical;
  }
}

// Loading state
.loading-slide {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 3rem;
  
  .loading-spinner {
    width: 50px;
    height: 50px;
    border: 4px solid var(--primary-low);
    border-top-color: var(--tertiary);
    border-radius: 50%;
    animation: spin 1s linear infinite;
    margin-bottom: 1rem;
  }
  
  p {
    color: var(--primary-medium);
    font-size: 1.1em;
  }
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

@media (max-width: 768px) {
  .swiper-topic-slide {
    padding: 1rem;
    
    .topic-slide-header h3 {
      font-size: 1.4em;
    }
    
    .topic-content {
      font-size: 0.95em;
    }
  }
}
```

## Usage Examples

### Example 1: Simple Topic Slideshow

```markdown
[wrap=swiper topics="123,456,789"]
[/wrap]
```

This will create a swiper with slides from topics 123, 456, and 789.

### Example 2: With Configuration

```markdown
[wrap=swiper topics="123,456,789" config="{navigation: {enabled: true}, pagination: {enabled: true}, autoHeight: true}"]
[/wrap]
```

### Example 3: Mixed Content

You can mix topics with images and other content:

```markdown
[wrap=swiper topics="123,456" config="{navigation: {enabled: true}}"]

<img src="/uploads/image.jpg" alt="Intro slide" />

<blockquote>
## Welcome
This is a text slide before the topics
</blockquote>

[/wrap]
```

The images and blockquotes will appear first, followed by the topic slides.

## PhotoSwipe Lightbox Integration

### Challenge

PhotoSwipe (pswp) is designed for images. To integrate cooked content slides:

1. **Create image proxies**: Generate thumbnail images for each topic slide
2. **Custom lightbox content**: Override PhotoSwipe's content renderer
3. **Alternative approach**: Use a custom modal instead of PhotoSwipe

### Recommended Approach: Custom Modal

Since PhotoSwipe is image-focused, I recommend creating a custom fullscreen modal for cooked content slides (similar to your collections-navigator modal):

```javascript
// In swiper-inline.gjs

showInOverlay(slideIndex) {
  // Create custom fullscreen modal
  const modal = document.createElement("div");
  modal.className = "swiper-fullscreen-modal";
  modal.innerHTML = `
    <div class="modal-container">
      <button class="modal-close">×</button>
      <div class="modal-content-area">
        <div class="swiper-container">
          <!-- Render full swiper here -->
        </div>
      </div>
      <div class="modal-nav">
        <button class="prev">Previous</button>
        <button class="next">Next</button>
      </div>
    </div>
  `;
  
  document.body.appendChild(modal);
  
  // Initialize swiper in modal starting at slideIndex
  // ...
}
```

Add click handler to slides:

```javascript
@action
handleSlideClick(index) {
  this.showInOverlay(index);
}
```

## Testing Checklist

- [ ] Topic IDs parse correctly from BBCode
- [ ] Topics fetch successfully via API
- [ ] Cooked content renders properly in slides
- [ ] Images within topic content work
- [ ] Lightbox/overlay opens correctly
- [ ] Navigation works (arrows, pagination)
- [ ] Responsive on mobile
- [ ] Loading states display properly
- [ ] Error handling for missing/deleted topics
- [ ] Works in composer preview
- [ ] Works in published post

## Security Considerations

1. **Topic Permissions**: The Discourse API respects topic permissions, so users will only see content they're allowed to view
2. **XSS Prevention**: Since we're using `htmlSafe`, ensure topic content is already sanitized by Discourse
3. **Rate Limiting**: Multiple topic fetches could hit rate limits. Consider:
   - Caching fetched topics
   - Limiting number of topics per swiper
   - Showing loading states

## Performance Optimization

1. **Lazy Loading**: Only fetch topic content when slide becomes active
2. **Caching**: Store fetched topics in browser cache
3. **Throttling**: Debounce rapid slide changes
4. **Pagination**: For many topics, consider pagination instead of loading all at once

## Alternative: Pre-rendered Topics

Instead of fetching topics client-side, you could:

1. Fetch topics server-side during post cooking
2. Inject cooked content directly into the BBCode output
3. Avoid async loading entirely

This would require a custom Discourse plugin rather than just a theme component.

## Next Steps

1. Implement Step 1-3 from the implementation guide
2. Test with a few topics first
3. Add error handling and loading states
4. Implement the custom fullscreen modal
5. Add CSS animations and transitions
6. Test thoroughly in different scenarios

## Questions to Consider

1. **Should topics auto-update?** If the source topic changes, should the swiper reflect that?
2. **How to handle deleted topics?** Show error slide or skip entirely?
3. **Privacy concerns?** Should there be limits on which topics can be embedded?
4. **Performance limits?** Maximum number of topics per swiper?
5. **Caching strategy?** How long to cache fetched content?

---

This implementation guide provides the foundation. The actual integration will require testing and refinement based on your specific Discourse setup and use cases.
