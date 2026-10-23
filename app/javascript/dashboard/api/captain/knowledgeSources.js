/* global axios */
import ApiClient from '../ApiClient';

class KnowledgeSources extends ApiClient {
  constructor() {
    super('captain/assistants', { accountScoped: true });
  }

  sourcesUrl(assistantId) {
    return `${this.url}/${assistantId}/website_sources`;
  }

  list(assistantId, signal) {
    return axios.get(this.sourcesUrl(assistantId), { signal });
  }

  discover(assistantId, websiteSource) {
    return axios.post(this.sourcesUrl(assistantId), {
      website_source: websiteSource,
    });
  }

  source(assistantId, sourceId, signal) {
    return axios.get(`${this.sourcesUrl(assistantId)}/${sourceId}`, { signal });
  }

  select(assistantId, sourceId, selectedUrls, autoAddPages) {
    return axios.patch(`${this.sourcesUrl(assistantId)}/${sourceId}`, {
      website_source: {
        selected_urls: selectedUrls,
        auto_add_pages: autoAddPages,
      },
    });
  }

  sections(assistantId, signal) {
    return axios.get(`${this.url}/${assistantId}/document_sections`, {
      signal,
    });
  }

  sectionAction(assistantId, sections, action) {
    return axios.post(`${this.url}/${assistantId}/document_sections`, {
      sections,
      section_action: action,
    });
  }

  rediscover(assistantId, sourceId) {
    return axios.post(`${this.sourcesUrl(assistantId)}/${sourceId}/rediscover`);
  }

  preview(assistantId, sourceId, url, signal) {
    return axios.post(
      `${this.sourcesUrl(assistantId)}/${sourceId}/preview`,
      { url },
      { signal }
    );
  }

  briefUrl(assistantId) {
    return `${this.url}/${assistantId}/knowledge_brief`;
  }

  brief(assistantId, signal) {
    return axios.get(this.briefUrl(assistantId), { signal });
  }

  // refresh asks for new examples right after the owner saved business details.
  examples(assistantId, { refresh = false } = {}) {
    return axios.get(`${this.briefUrl(assistantId)}/examples`, {
      params: refresh ? { refresh: true } : {},
    });
  }

  generateBrief(assistantId, documentIds) {
    return axios.post(`${this.briefUrl(assistantId)}/generate`, {
      document_ids: documentIds,
    });
  }

  publishBrief(assistantId, brief) {
    return axios.post(`${this.briefUrl(assistantId)}/publish`, { brief });
  }

  disableBrief(assistantId) {
    return axios.patch(this.briefUrl(assistantId));
  }
}

export default new KnowledgeSources();
