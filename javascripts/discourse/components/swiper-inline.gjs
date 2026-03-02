import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { cached } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { and, eq } from "truth-helpers";
import { on } from "@ember/modifier";
import noop from "discourse/helpers/noop";
import lightbox from "discourse/lib/lightbox";
import loadScript from "discourse/lib/load-script";
import { deepMerge } from "discourse/lib/object";
import { escapeExpression } from "discourse/lib/utilities";
import { DEFAULT_SETTINGS } from "../lib/constants";
import { normalizeSettings } from "../lib/utils";
import TopicFetcher from "../lib/topic-fetcher";

export default class SwiperInline extends Component {
  @service siteSettings;
  @service activeSwiperInEditor;
  @tracked topicSlides = [];
  @tracked isLoadingTopics = false;
  @tracked overlayModal = null;
  @tracked overlaySwiper = null;

  constructor() {
    super(...arguments);
    
    // If topics are specified, fetch them
    if (this.args.topicIds && this.args.topicIds.length > 0) {
      this.loadTopicSlides();
    }
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.closeOverlay();
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
        thumbnailNode: this.createTopicThumbnail(topic),
        node: this.createTopicSlideNode(topic),
        caption: null,
      }));
      
      // Reinitialize swiper with new slides if already initialized
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

  createTopicSlideNode(topic) {
    // Create the actual slide content node
    const div = document.createElement("div");
    div.className = "topic-slide-content";
    div.innerHTML = `
      <div class="topic-slide-header">
        <h3>${escapeExpression(topic.title)}</h3>
      </div>
      <div class="topic-slide-body">
        ${topic.cooked}
      </div>
    `;
    return div;
  }

  createTopicThumbnail(topic) {
    // Create a thumbnail element from topic data for navigation
    const div = document.createElement("div");
    div.className = "topic-thumbnail";
    div.innerHTML = `
      <div class="topic-thumbnail-title">${escapeExpression(topic.title)}</div>
      ${topic.excerpt ? `<div class="topic-thumbnail-excerpt">${escapeExpression(topic.excerpt)}</div>` : ""}
    `;
    return div;
  }

  @cached
  get allSlides() {
    // Combine regular parsed data with topic slides
    const regular = this.args.data?.parsedData || [];
    return [...regular, ...this.topicSlides];
  }

  async loadSwiper() {
    await loadScript(settings.theme_uploads_local.swiper_js);
  }

  @action
  async destroySwiper() {
    this.mainSlider?.destroy(true, true);
    this.thumbSlider?.destroy(true, true);
  }

  @action
  didUpdateAttrs() {
    this.destroySwiper();
    this.initializeSwiper(this.swiperWrapElement);
  }

  @action
  handleSlideClick(index, event) {
    // Don't open overlay if clicking on a link or lightbox image
    if (event.target.closest('a, .lightbox-wrapper')) {
      return;
    }
    
    const slide = this.allSlides[index];
    // Only open overlay for topic slides and cooked content
    if (slide?.type === "topic-slide" || slide?.type === "cooked" || slide?.type === "textcontent") {
      this.showInOverlay(index);
    }
  }

  @action
  showInOverlay(slideIndex) {
    // Create custom fullscreen modal
    const modal = document.createElement("div");
    modal.className = "swiper-fullscreen-modal";
    
    // Build slides HTML
    const slidesHtml = this.allSlides.map((data, idx) => {
      let slideContent = '';
      
      if (data.type === "topic-slide") {
        slideContent = `
          <div class="swiper-topic-slide">
            ${data.node.outerHTML}
          </div>
        `;
      } else if (data.type === "cooked") {
        slideContent = `
          <div class="swiper-cooked-wrapper">
            <div class="cooked-content">
              ${data.node.outerHTML}
            </div>
          </div>
        `;
      } else if (data.type === "textcontent") {
        slideContent = `
          <div class="swiper-text-wrapper">
            <div class="text-content">
              ${data.node.outerHTML}
            </div>
          </div>
        `;
      } else if (data.type === "image") {
        slideContent = data.node.outerHTML;
      } else if (data.type === "iframe") {
        slideContent = `
          <div class="swiper-iframe-wrapper">
            ${data.node.outerHTML}
          </div>
        `;
      }
      
      return `<div class="swiper-slide">${slideContent}</div>`;
    }).join('');
    
    modal.innerHTML = `
      <div class="modal-container">
        <button class="modal-close" aria-label="Close">&times;</button>
        <div class="modal-content-area">
          <div class="swiper modal-swiper">
            <div class="swiper-wrapper">
              ${slidesHtml}
            </div>
            <div class="swiper-button-next"><span class="arrow-icon"></span></div>
            <div class="swiper-button-prev"><span class="arrow-icon"></span></div>
            <div class="swiper-pagination"></div>
          </div>
        </div>
      </div>
    `;
    
    document.body.appendChild(modal);
    this.overlayModal = modal;
    
    // Initialize overlay swiper
    const modalSwiperEl = modal.querySelector('.modal-swiper');
    this.overlaySwiper = new window.Swiper(modalSwiperEl, {
      initialSlide: slideIndex,
      direction: 'horizontal',
      navigation: {
        nextEl: '.swiper-button-next',
        prevEl: '.swiper-button-prev',
      },
      pagination: {
        el: '.swiper-pagination',
        type: 'fraction',
      },
      keyboard: {
        enabled: true,
      },
      autoHeight: true,
    });
    
    // Event listeners
    const closeBtn = modal.querySelector('.modal-close');
    closeBtn.addEventListener('click', () => this.closeOverlay());
    
    // Close on background click
    modal.addEventListener('click', (e) => {
      if (e.target === modal) {
        this.closeOverlay();
      }
    });
    
    // Close on Escape key
    const escapeHandler = (e) => {
      if (e.key === 'Escape') {
        this.closeOverlay();
      }
    };
    document.addEventListener('keydown', escapeHandler);
    modal.dataset.escapeHandler = 'attached';
    
    // Prevent body scroll
    document.body.style.overflow = 'hidden';
  }

  @action
  closeOverlay() {
    if (this.overlaySwiper) {
      this.overlaySwiper.destroy(true, true);
      this.overlaySwiper = null;
    }
    
    if (this.overlayModal) {
      this.overlayModal.remove();
      this.overlayModal = null;
    }
    
    // Restore body scroll
    document.body.style.overflow = '';
  }

  @action
  async initializeSwiper(element) {
    this.swiperWrapElement = element;

    await this.loadSwiper();

    if (this.config.thumbs.enabled) {
      this.thumbSlider = new window.Swiper(
        this.swiperWrapElement.querySelector(".slider-thumb"),
        {
          spaceBetween: this.config.thumbs.spaceBetween,
          direction: this.config.thumbs.direction,
          slidesPerView: this.config?.thumbs.slidesPerView,
          freeMode: true,
          watchSlidesProgress: true,
        }
      );
    }

    function hoverThumbs({ swiper, extendParams, on }) {
      extendParams({
        hoverThumbs: {
          enabled: false,
          swiper: null,
        },
      });

      on("init", function () {
        const params = swiper.params.hoverThumbs;
        if (!params.enabled || !params.swiper) {
          return;
        }

        params.swiper.slides.forEach((slide, index) => {
          slide.addEventListener("mouseenter", () => {
            swiper.slideTo(index);
          });
        });
      });

      on("destroy", function () {
        const params = swiper.params.hoverThumbs;
        if (!params.enabled || !params.swiper) {
          return;
        }

        params.swiper.slides.forEach((slide, index) => {
          slide.removeEventListener("mouseenter", () => {
            swiper.slideTo(index);
          });
        });
      });
    }

    const slideElement = this.swiperWrapElement.querySelector(".main-slider");

    this.mainSlider = new window.Swiper(slideElement, {
      enabled: true,

      direction: this.config.direction,
      slidesPerView: this.config.slidesPerView,
      slidesPerGroup: this.config.slidesPerGroup,
      centeredSlides: this.config.centeredSlides,
      spaceBetween: this.config.spaceBetween,
      grid: {
        rows: this.config.grid.rows,
      },

      autoplay: this.config.autoplay.enabled
        ? {
            delay: this.config.autoplay.delay,
            pauseOnMouseEnter: this.config.autoplay.pauseOnMouseEnter,
            disableOnInteraction: this.config.autoplay.disableOnInteraction,
            reverseDirection: this.config.autoplay.reverseDirection,
            stopOnLastSlide: this.config.autoplay.stopOnLast,
          }
        : false,

      autoHeight: this.config.autoHeight,

      loop: this.config.loop,
      rewind: this.config.rewind,

      speed: this.config.speed,
      effect: this.config.effect,

      fadeEffect: {
        crossFade: this.config.crossfade,
      },

      navigation: {
        enabled: this.config.navigation.enabled,
        hideOnClick: this.config.navigation.hideOnClick,
        placement: this.config.navigation.placement,
        nextEl: ".swiper-button-next",
        prevEl: ".swiper-button-prev",
        addIcons: false,
      },

      pagination: this.config.pagination.enabled
        ? {
            clickable: this.config.pagination.clickable,
            type: this.config.pagination.type,
            el: ".swiper-pagination",
          }
        : false,

      keyboard: {
        enabled: this.config?.keyboard,
      },
      mousewheel: {
        invert: false,
        enabled: false,
      },

      thumbs: {
        swiper: this.config.thumbs.enabled && this.thumbSlider,
      },

      cubeEffect: {
        shadow: false,
        slideShadows: false,
        shadowOffset: 20,
        shadowScale: 0.94,
      },
      coverflowEffect: {
        rotate: 50,
        stretch: 0,
        depth: 100,
        modifier: 1,
        slideShadows: true,
      },

      hoverThumbs: {
        enabled: this.config.thumbs.enabled && this.config.thumbs.slideOnHover,
        swiper: this.thumbSlider,
      },

      modules: [hoverThumbs],
    });

    this.activeSwiperInEditor.setTo(this.mainSlider);

    if (this.config.navigation !== null) {
      slideElement.classList.remove("swiper-navigation-disabled");

      ["inside", "outside"].forEach((placement) =>
        ["horizontal", "vertical"].forEach((direction) =>
          this.swiperWrapElement.classList.remove(
            `swiper-navigation-${placement}--${direction}`
          )
        )
      );

      if (!this.config.navigation.enabled) {
        return;
      }

      this.swiperWrapElement.classList.add(
        `swiper-navigation-${this.config.navigation.placement}--${this.config.direction}`
      );

      if (this.config.navigation.placement === "outside") {
        this.swiperWrapElement.style.setProperty(
          "--swiper-navigation-sides-offset",
          "0"
        );
      }

      if (this.config.navigation.position === "top") {
        this.swiperWrapElement.style.setProperty(
          "--swiper-navigation-top-offset",
          "10%"
        );
      } else if (this.config.navigation.position === "center") {
        this.swiperWrapElement.style.setProperty(
          "--swiper-navigation-top-offset",
          "50%"
        );
      } else if (this.config.navigation.position === "bottom") {
        this.swiperWrapElement.style.setProperty(
          "--swiper-navigation-top-offset",
          "90%"
        );
      }

      if (this.config.navigation.color) {
        this.swiperWrapElement.style.setProperty(
          "--swiper-navigation-color",
          this.config.navigation.color
        );
      }
    }

    // Post view
    if (this.args.data && !this.args.data.preview) {
      lightbox(this.swiperWrapElement, this.siteSettings);
    }

    if (this.config.mode !== "edit" && Object.keys(this.config).length > 0) {
      if (this.config.width) {
        this.swiperWrapElement.parentElement.style.width = htmlSafe(
          escapeExpression(this.config.width)
        );
      }

      if (this.config.height) {
        this.swiperWrapElement.parentElement.style.height = htmlSafe(
          escapeExpression(this.config.height)
        );

        this.swiperWrapElement.firstElementChild.style.height = htmlSafe(
          escapeExpression(this.config.height)
        );
      }
    }
  }

  @cached
  get config() {
    return normalizeSettings(
      deepMerge(
        {},
        DEFAULT_SETTINGS,
        this.args.data?.config || this.args.node?.config || {}
      )
    );
  }

  <template>
    <div
      class="swiper-wrap"
      {{didInsert this.initializeSwiper}}
      {{didInsert (if @node.onSetup @node.onSetup (noop))}}
      {{didUpdate this.didUpdateAttrs @node}}
      {{willDestroy this.destroySwiper}}
    >
      <div class="swiper main-slider">
        <div class="swiper-wrapper">
          {{#if this.isLoadingTopics}}
            <div class="swiper-slide loading-slide">
              <div class="loading-spinner"></div>
              <p>Loading topics...</p>
            </div>
          {{else if @node.images}}
            {{#each @node.images as |node|}}
              <div class="swiper-slide">
                <img
                  draggable="false"
                  src={{node.attrs.src}}
                  alt={{node.attrs.alt}}
                  title={{node.attrs.title}}
                  width={{node.attrs.width}}
                  height={{node.attrs.height}}
                  data-orig-src={{node.attrs.originalSrc}}
                  data-scale={{node.attrs.scale}}
                  data-thumbnail={{if
                    (eq node.attrs.extras "thumbnail")
                    "true"
                  }}
                />
              </div>
            {{/each}}
          {{else}}
            {{#each this.allSlides as |data index|}}
              <div 
                class="swiper-slide" 
                {{on "click" (fn this.handleSlideClick index)}}
                role={{if (eq data.type "topic-slide") "button" ""}}
                tabindex={{if (eq data.type "topic-slide") "0" ""}}
              >
                {{#if (eq data.type "image")}}
                  {{data.node}}

                {{else if (eq data.type "iframe")}}
                  <div class="swiper-iframe-wrapper">
                    {{data.node}}
                  </div>
                  {{#if data.caption}}
                    <div class="swiper-slide-content">
                      {{htmlSafe data.caption}}
                    </div>
                  {{/if}}

                {{else if (eq data.type "cooked")}}
                  <div class="swiper-cooked-wrapper">
                    <div class="cooked-content">
                      {{data.node}}
                    </div>
                  </div>
                  {{#if data.caption}}
                    <div class="swiper-slide-content">
                      {{htmlSafe data.caption}}
                    </div>
                  {{/if}}

                {{else if (eq data.type "textcontent")}}
                  <div class="swiper-text-wrapper">
                    <div class="text-content">
                      {{data.node}}
                    </div>
                  </div>
                  {{#if data.caption}}
                    <div class="swiper-slide-content">
                      {{htmlSafe data.caption}}
                    </div>
                  {{/if}}

                {{else if (eq data.type "topic-slide")}}
                  <div class="swiper-topic-slide">
                    {{data.node}}
                  </div>
                  {{#if data.caption}}
                    <div class="swiper-slide-content">
                      {{htmlSafe data.caption}}
                    </div>
                  {{/if}}

                {{/if}}
              </div>
            {{/each}}
          {{/if}}
        </div>
        {{#if
          (and
            (eq this.config.navigation.enabled true)
            (eq this.config.navigation.placement "inside")
          )
        }}
          <div class="swiper-button-next" contenteditable="false">
            <span class="arrow-icon"></span>
          </div>
          <div class="swiper-button-prev" contenteditable="false">
            <span class="arrow-icon"></span>
          </div>
        {{/if}}
        {{#if
          (and
            (eq this.config.pagination.enabled true)
            (eq this.config.pagination.placement "inside")
          )
        }}
          <div class="swiper-pagination"></div>
        {{/if}}
      </div>

      {{#if
        (and
          (eq this.config.navigation.enabled true)
          (eq this.config.navigation.placement "outside")
        )
      }}
        <div class="swiper-button-next" contenteditable="false">
          <span class="arrow-icon"></span>
        </div>
        <div class="swiper-button-prev" contenteditable="false">
          <span class="arrow-icon"></span>
        </div>
      {{/if}}

      {{#if this.config.thumbs.enabled}}
        <div
          thumbsSlider=""
          class="swiper slider-thumb --{{this.config.thumbs.direction}}"
        >
          <div class="swiper-wrapper">
            {{#if @node.images}}
              {{#each @node.images as |node|}}
                <div class="swiper-slide">
                  <img
                    draggable="false"
                    src={{node.attrs.src}}
                    alt={{node.attrs.alt}}
                    title={{node.attrs.title}}
                    width={{node.attrs.width}}
                    height={{node.attrs.height}}
                    data-orig-src={{node.attrs.originalSrc}}
                    data-scale={{node.attrs.scale}}
                    data-thumbnail={{if
                      (eq node.attrs.extras "thumbnail")
                      "true"
                    }}
                  />
                </div>
              {{/each}}

            {{else}}
              {{#each this.allSlides as |data|}}
                <div class="swiper-slide">
                  {{data.thumbnailNode}}
                </div>
              {{/each}}
            {{/if}}
          </div>
        </div>
      {{/if}}

      {{#if
        (and
          (eq this.config.pagination.enabled true)
          (eq this.config.pagination.placement "outside")
        )
      }}
        <div class="swiper-pagination"></div>
      {{/if}}
    </div>
  </template>
}
