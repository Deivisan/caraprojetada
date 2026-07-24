// CaraProjetada TabMirror - Popup Logic

document.addEventListener('DOMContentLoaded', () => {
  loadTabs();
  checkStatus();
  
  document.getElementById('refresh-tabs').addEventListener('click', loadTabs);
});

async function loadTabs() {
  const tabsList = document.getElementById('tabs-list');
  
  try {
    const response = await chrome.runtime.sendMessage({ action: 'getTabs' });
    
    if (response.tabs && response.tabs.length > 0) {
      tabsList.innerHTML = response.tabs.map(tab => `
        <div class="tab-item" data-tab-id="${tab.id}">
          <div class="tab-item-title">${escapeHtml(tab.title)}</div>
          <div class="tab-item-url">${escapeHtml(tab.url)}</div>
        </div>
      `).join('');
      
      // Add click handlers
      document.querySelectorAll('.tab-item').forEach(el => {
        el.addEventListener('click', () => mirrorTab(parseInt(el.dataset.tabId)));
      });
    } else {
      tabsList.innerHTML = '<p style="text-align: center; color: #666;">Nenhuma aba encontrada</p>';
    }
  } catch (error) {
    tabsList.innerHTML = `<p style="color: #f44336; text-align: center;">Erro: ${error.message}</p>`;
  }
}

async function mirrorTab(tabId) {
  const statusEl = document.getElementById('status');
  const statusDetail = document.getElementById('status-detail');
  
  statusEl.className = 'status';
  statusDetail.textContent = 'Conectando ao projetor...';
  
  try {
    const response = await chrome.runtime.sendMessage({ 
      action: 'mirrorTab', 
      tabId: tabId 
    });
    
    if (response.success) {
      statusEl.className = 'status connected';
      statusDetail.textContent = 'Aba espelhada com sucesso!';
      
      // Highlight selected tab
      document.querySelectorAll('.tab-item').forEach(el => el.classList.remove('active'));
      document.querySelector(`[data-tab-id="${tabId}"]`).classList.add('active');
      
      setTimeout(loadTabs, 2000);
    } else {
      throw new Error(response.error || 'Falha ao espelhar aba');
    }
  } catch (error) {
    statusEl.className = 'status disconnected';
    statusDetail.textContent = `Erro: ${error.message}`;
  }
}

async function checkStatus() {
  const statusEl = document.getElementById('status');
  const statusDetail = document.getElementById('status-detail');
  
  try {
    const response = await chrome.runtime.sendMessage({ action: 'testConnection' });
    
    if (response.connected) {
      statusEl.className = 'status connected';
      statusDetail.textContent = `Conectado - ${response.projector_ip || 'disponível'}`;
    } else {
      statusEl.className = 'status disconnected';
      statusDetail.textContent = 'Projetor offline';
    }
  } catch (error) {
    statusEl.className = 'status disconnected';
    statusDetail.textContent = 'Não foi possível conectar';
  }
}

function escapeHtml(text) {
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}