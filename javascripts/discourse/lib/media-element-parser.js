// [
//   {
//     type: <type>,
//     node: <element>,
//     caption: <html>"
//   },
//   {
//     type: "nested-swiper",
//     items: [
//       {
//         type: <type>,
//         node: <element>,
//         caption: <html>
//       },
//       ...
//     ]
//   }
// ]
//

export default class MediaElementParser {
  /**
   * Parses a DOM root element and extract media elements with captions
   * Captions are any element following the media element until another media element or non-paragraph element
   *
   * Extended to support iframes, blockquotes, and details elements as content slides
   *
   * @param {HTMLElement} root
   * @returns {Array} items
   */
  static run(root) {
    const items = [];
    const nodes = Array.from(root.childNodes);

    for (let i = 0; i < nodes.length; i++) {
      const node = nodes[i];

      if (this.isWrap(node)) {
        items.push({ type: "nested", items: this.run(node) });
        continue;
      }

      // Handle iFrames
      if (this.isIframe(node)) {
        const captionHtml = this.extractFollowingCaption(nodes, i + 1);
        this.pushMediaItem(items, "iframe", node, captionHtml);
        continue;
      }

      // NEW: Handle blockquote elements as text content slides
      if (this.isBlockquote(node)) {
        const captionHtml = this.extractFollowingCaption(nodes, i + 1);
        this.pushMediaItem(items, "textcontent", node, captionHtml);
        continue;
      }

      // NEW: Handle details elements as text content slides
      if (this.isDetails(node)) {
        const captionHtml = this.extractFollowingCaption(nodes, i + 1);
        this.pushMediaItem(items, "textcontent", node, captionHtml);
        continue;
      }

      // Original: Handle cooked content blocks (kept for backward compatibility, though unlikely to work)
      if (this.isCookedContent(node)) {
        const captionHtml = this.extractFollowingCaption(nodes, i + 1);
        this.pushMediaItem(items, "cooked", node, captionHtml);
        continue;
      }

      if (this.isVideo(node) || this.isImage(node)) {
        const captionHtml = this.extractFollowingCaption(nodes, i + 1);

        this.pushMediaItem(
          items,
          this.isVideo(node) ? "video" : "image",
          node,
          captionHtml
        );
        continue;
      }

      if (this.isParagraph(node)) {
        const images = Array.from(node.querySelectorAll("span.image-wrapper"));
        if (images.length) {
          for (const img of images) {
            const inlineHtml = this.extractInlineCaptionAfterImage(node, img);
            const followingHtml = this.extractFollowingCaption(nodes, i + 1);
            const captionHtml = (inlineHtml + followingHtml).trim();
            this.pushMediaItem(items, "image", img, captionHtml);
          }
        }
        continue;
      }
    }

    return items;
  }

  static pushMediaItem(items, type, node, captionHtml) {
    items.push({
      type,
      node: node.cloneNode(true),
      thumbnailNode:
        type === "image"
          ? node.tagName === "IMG"
            ? node.cloneNode(true)
            : node.querySelector("img:not(.emoji)")?.cloneNode(true)
          : type === "textcontent" || type === "cooked"
          ? this.createTextThumbnail(node)
          : null,
      caption: this.wrapCaption(captionHtml),
    });
  }

  // NEW: Detect blockquote elements
  static isBlockquote(node) {
    return (
      node.nodeType === Node.ELEMENT_NODE &&
      node.tagName === "BLOCKQUOTE"
    );
  }

  // NEW: Detect details elements
  static isDetails(node) {
    return (
      node.nodeType === Node.ELEMENT_NODE &&
      node.tagName === "DETAILS"
    );
  }

  // Detect iFrame elements
  static isIframe(node) {
    return (
      node.nodeType === Node.ELEMENT_NODE &&
      (node.tagName === "IFRAME" ||
        node.matches?.("iframe") ||
        node.querySelector?.("iframe"))
    );
  }

  // Detect cooked content blocks (marked with specific class or data attribute)
  static isCookedContent(node) {
    return (
      node.nodeType === Node.ELEMENT_NODE &&
      (node.matches?.(".cooked-content") ||
        node.matches?.(".swiper-cooked-slide") ||
        node.matches?.("[data-swiper-cooked]") ||
        node.classList?.contains("cooked-content") ||
        node.classList?.contains("swiper-cooked-slide"))
    );
  }

  // NEW: Create thumbnail for text content (first text or heading)
  static createTextThumbnail(node) {
    const thumbnail = document.createElement("div");
    thumbnail.className = "text-thumbnail";
    
    // Try to get heading text first
    const heading = node.querySelector("h1, h2, h3, h4, h5, h6");
    if (heading) {
      thumbnail.textContent = heading.textContent?.trim().substring(0, 50) || "Text Slide";
      return thumbnail;
    }
    
    // Fall back to first paragraph or summary
    const firstP = node.querySelector("p, summary");
    if (firstP) {
      const text = firstP.textContent?.trim().substring(0, 50) || "Content";
      thumbnail.textContent = text + (text.length >= 50 ? "..." : "");
      return thumbnail;
    }
    
    // Ultimate fallback
    const textContent = node.textContent?.trim().substring(0, 50) || "Text Slide";
    thumbnail.textContent = textContent + (textContent.length >= 50 ? "..." : "");
    return thumbnail;
  }

  static isParagraph(node) {
    return node.nodeType === Node.ELEMENT_NODE && node.tagName === "P";
  }

  static isImage(node) {
    return (
      node.nodeType === Node.ELEMENT_NODE &&
      (node.matches?.(".image-wrapper") ||
        node.matches?.(".lightbox-wrapper") ||
        node.matches?.("img:not(.emoji)"))
    );
  }

  static isVideo(node) {
    return (
      node.nodeType === Node.ELEMENT_NODE &&
      node.matches?.("div.onebox-placeholder-container")
    );
  }

  static isWrap(node) {
    return node.nodeType === Node.ELEMENT_NODE && node.matches?.("div.d-wrap");
  }

  // Collect subsequent <p> elements (until a wrap/video/iframe/blockquote/details/element that's not <p>)
  static extractFollowingCaption(nodes, startIndex) {
    let html = "";

    for (let i = startIndex; i < nodes.length; i++) {
      const n = nodes[i];

      if (this.isWrap(n) || this.isVideo(n) || this.isIframe(n) || 
          this.isBlockquote(n) || this.isDetails(n) || this.isCookedContent(n)) {
        break;
      }

      if (this.isParagraph(n)) {
        if (n.querySelector("span.image-wrapper")) {
          break;
        }
        html += n.innerHTML + "<br>";
        continue;
      }

      // stop at other element nodes
      if (n.nodeType === Node.ELEMENT_NODE) {
        break;
      }
    }

    return this.trimBr(html);
  }

  // Extract html that appears after an image inside the same paragraph
  static extractInlineCaptionAfterImage(paragraph, imageNode) {
    let html = "";
    let seenImage = false;

    for (const child of paragraph.childNodes) {
      if (!seenImage) {
        if (child === imageNode) {
          seenImage = true;
        }
        continue;
      }
      // if another image element appears after, stop
      if (this.isImage(child)) {
        break;
      }
      html += child.outerHTML ?? child.textContent;
    }

    return this.trimBr(html);
  }

  static trimBr(html) {
    return html.replace(/^(<br\s*\/?>)+/i, "").replace(/(<br\s*\/?>)+$/i, "");
  }

  static wrapCaption(html) {
    if (!html || !html.trim()) {
      return null;
    }
    return `<div class="caption">${html.trim()}</div>`;
  }
}
