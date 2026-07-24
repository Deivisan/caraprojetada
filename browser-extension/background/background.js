// CaraProjetada TabMirror - Background Service Worker
// Comunicação com o projetor via WebSocket e REST API

class CaraProjetadaClient {
  constructor() {
    this.apiBase = 'http://projetores.intranet.ufrb.edu.br/api/v1';
    this.ws = null;
    this.sessionId = null;
    this.currentTab = null;
    this.init();
  }

  init() {
    chrome.runtime.onInstalled.addListener(() => {
      console.log('CaraProjetada TabMirror instalado');
      this.loadSettings();
    });

    // Listen for messages from popup/content
    chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
      if (request.action === 'getTabs') {
        this.getTabs().then(sendResponse);
        return true;
      }
      if (request.action === 'mirrorTab') {
        this.mirrorTab(request.tabId).then(sendResponse);
        return true;
      }
      if (request.action === 'testConnection') {
        this.testConnection().then(sendResponse);
        return true;
      }
    });
  }

  async getTabs() {
    const tabs = await chrome.tabs.query({});
    return {
      tabs: tabs.map(tab => ({
        id: tab.id,
        title: tab.title,
        url: tab.url,
        active: tab.active,
        windowId: tab.windowId,
        favIconUrl: tab.favIconUrl
      }))
    };
  }

  async mirrorTab(tabId) {
    const [tab] = await chrome.tabs.get(tabId);
    if (!tab) return { success: false, error: 'Tab não encontrada' };

    const response = await fetch(`${this.apiBase}/tab`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        tab_id: tab.id,
        url: tab.url,
        title: tab.title,
        window_id: tab.windowId
      })
    });

    return await response.json();
  }

  async testConnection() {
    try {
      const response = await fetch(`${this.apiBase}/status`);
      return await response.json();
    } catch (error) {
      return { connected: false, error: error.message };
    }
  }

  async loadSettings() {
    const settings = await chrome.storage.sync.get(['projectorIp', 'apiKey']);
    if (!settings.projectorIp) {
      await chrome.storage.sync.set({ 
        projectorIp: 'projetores.intranet.ufrb.edu.br' 
      });
    }
  }
}

// Initialize client
new CaraProjetadaClient();