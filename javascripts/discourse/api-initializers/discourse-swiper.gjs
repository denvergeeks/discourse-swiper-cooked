import { camelize } from "@ember/string";
import { apiInitializer } from "discourse/lib/api";
import SwiperInline from "../components/swiper-inline";
import MediaElementParser from "../lib/media-element-parser";
import swiperExtension from "../lib/rich-editor-extension";
import { parseWrapParam } from "../lib/utils";

export default apiInitializer((api) => {
  initializeSwiper(api);
});

function initializeSwiper(api) {
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

  api.decorateCookedElement((element, helper) => {
    element
      .querySelectorAll("[data-wrap=swiper]")
      .forEach((swiper) => applySwiper(swiper, helper));
  });

  api.registerRichEditorExtension(swiperExtension);

  window.I18n.translations[window.I18n.locale].js.composer.swiper_sample = "";

  api.addComposerToolbarPopupMenuOption({
    icon: "images",
    label: themePrefix("insert_swiper_sample"),
    action: (toolbarEvent) => {
      toolbarEvent.applySurround(
        "\n[wrap=swiper]\n",
        "\n[/wrap]\n",
        "swiper_sample",
        {
          multiline: false,
        }
      );
    },
  });
}
