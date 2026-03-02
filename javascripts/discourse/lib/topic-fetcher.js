// Utility to fetch topic content from Discourse API
// Used to populate swiper slides with cooked content from other topics

export default class TopicFetcher {
  /**
   * Fetch cooked content from a topic by ID
   * @param {number} topicId - The Discourse topic ID
   * @param {number} postNumber - Optional post number (defaults to first post)
   * @returns {Promise<Object>} Object with title, cooked content, and metadata
   */
  static async fetchTopicContent(topicId, postNumber = 1) {
    try {
      const response = await fetch(`/t/${topicId}.json`);
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }
      
      const data = await response.json();
      
      // Find the specific post (usually first post)
      const post = data.post_stream?.posts?.find(p => p.post_number === postNumber) 
                   || data.post_stream?.posts?.[0];
      
      if (!post) {
        throw new Error(`No post found for topic ${topicId}`);
      }
      
      return {
        topicId: data.id,
        title: data.title || "Untitled",
        cooked: post.cooked || "<p>No content</p>",
        excerpt: data.excerpt || "",
        categoryId: data.category_id,
        tags: data.tags || [],
        createdAt: post.created_at,
        username: post.username,
        avatarTemplate: post.avatar_template,
      };
    } catch (error) {
      console.error(`Error fetching topic ${topicId}:`, error);
      return {
        topicId,
        title: "Error Loading Topic",
        cooked: `<p>Could not load topic content: ${error.message}</p>`,
        error: error.message,
      };
    }
  }

  /**
   * Fetch multiple topics in parallel
   * @param {Array<number>} topicIds - Array of topic IDs
   * @returns {Promise<Array>} Array of topic content objects
   */
  static async fetchMultipleTopics(topicIds) {
    const promises = topicIds.map(id => this.fetchTopicContent(id));
    return Promise.all(promises);
  }

  /**
   * Parse topic IDs from BBCode attributes or content
   * Supports formats:
   * - topics="123,456,789"
   * - topics="123 456 789"
   * - data-topics="123,456,789"
   * @param {HTMLElement|Object} element - Element or dataset object
   * @returns {Array<number>} Array of topic IDs
   */
  static parseTopicIds(element) {
    const dataset = element.dataset || element;
    const topicsAttr = dataset.topics || dataset.topicIds || "";
    
    if (!topicsAttr) {
      return [];
    }
    
    // Parse comma or space separated IDs
    return topicsAttr
      .split(/[,\s]+/)
      .map(id => parseInt(id.trim(), 10))
      .filter(id => !isNaN(id) && id > 0);
  }
}
