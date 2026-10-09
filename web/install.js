(() => {
  const dialog = document.querySelector('#install-dialog');
  const download = document.querySelector('#download-offline');
  const status = document.querySelector('#offline-status');
  const install = document.querySelector('#install-native');
  let promptEvent = null;
  let platform = 'android';
  const standalone = () => matchMedia('(display-mode: standalone)').matches || navigator.standalone === true;

  function showInstructions() {
    document.querySelector('#install-title').textContent = platform === 'ios' ? 'Lume no iPhone / iPad' : 'Lume no Android';
    document.querySelector('#install-help').textContent = standalone()
      ? 'Você já está usando o aplicativo pela tela inicial.'
      : platform === 'ios'
        ? 'No Safari, toque em Compartilhar → Adicionar à Tela de Início. Ative “Abrir como App”, se aparecer, e toque em Adicionar. Se abriu por WhatsApp ou Instagram, abra este link no Safari primeiro.'
        : 'No Chrome, abra o menu ⋮ e escolha “Instalar aplicativo” ou “Adicionar à tela inicial”. Se abriu por WhatsApp ou Instagram, abra este link no Chrome primeiro.';
    install.hidden = !promptEvent || platform === 'ios' || standalone();
  }

  window.addEventListener('beforeinstallprompt', event => {
    event.preventDefault();
    promptEvent = event;
    showInstructions();
  });
  window.addEventListener('appinstalled', () => {
    promptEvent = null;
    install.hidden = true;
    document.querySelector('#install-help').textContent = 'Instalado! Abra Lume pela tela inicial.';
  });
  install.onclick = async () => {
    if (!promptEvent) return;
    const event = promptEvent;
    promptEvent = null;
    install.hidden = true;
    try { await event.prompt(); await event.userChoice; }
    catch { /* The browser menu remains available. */ }
  };

  function workerRequest(worker, message, timeout = 15000) {
    return new Promise((resolve, reject) => {
      const channel = new MessageChannel();
      const timer = setTimeout(() => { channel.port1.close(); reject(new Error('timeout')); }, timeout);
      channel.port1.onmessage = event => {
        clearTimeout(timer);
        channel.port1.close();
        resolve(event.data);
      };
      worker.postMessage(message, [channel.port2]);
    });
  }

  async function checkOffline() {
    if (!('serviceWorker' in navigator)) return false;
    const registration = await navigator.serviceWorker.getRegistration('./');
    const worker = registration?.waiting || registration?.active;
    if (!worker) return false;
    const result = await workerRequest(worker, {type: 'CHECK_OFFLINE'});
    if (result.ready) {
      status.textContent = registration.waiting
        ? 'Atualização baixada. Feche todas as janelas do Lume e abra novamente para usá-la.'
        : 'Download concluído. O jogo está disponível offline neste aplicativo ou navegador.';
      download.textContent = 'Verificar atualizações';
    }
    return result.ready;
  }

  document.querySelectorAll('[data-install]').forEach(button => {
    button.onclick = () => {
      platform = button.dataset.install;
      showInstructions();
      dialog.showModal();
      checkOffline().catch(() => {});
    };
  });

  if (!('serviceWorker' in navigator) || !isSecureContext) {
    download.disabled = true;
    status.textContent = 'O download offline não está disponível neste navegador. Abra o link HTTPS no Safari ou Chrome atualizado.';
    return;
  }
  navigator.serviceWorker.addEventListener('message', event => {
    if (event.data?.type === 'DOWNLOAD_PROGRESS' && download.disabled) {
      status.textContent = `Baixando arquivos do jogo… ${event.data.done} de ${event.data.total}. Aguarde nesta página.`;
    }
  });
  download.onclick = async () => {
    download.disabled = true;
    status.textContent = 'Preparando download… mantenha esta página aberta.';
    try {
      const registration = await navigator.serviceWorker.register('./sw.js', {scope: './', updateViaCache: 'none'});
      await registration.update();
      const worker = registration.installing || registration.waiting || registration.active;
      if (!worker) throw new Error('missing worker');
      if (worker.state !== 'activated') {
        await new Promise((resolve, reject) => {
          const timer = setTimeout(() => { cleanup(); reject(new Error('timeout')); }, 240000);
          const cleanup = () => { clearTimeout(timer); worker.removeEventListener('statechange', changed); };
          const changed = () => {
            if (worker.state === 'activated' || (worker.state === 'installed' && registration.active)) { cleanup(); resolve(); }
            if (worker.state === 'redundant') { cleanup(); reject(new Error('download failed')); }
          };
          worker.addEventListener('statechange', changed);
          changed();
        });
      }
      if (!await checkOffline()) {
        // Browsers may evict files without unregistering the worker.
        await workerRequest(registration.waiting || registration.active, {type: 'REPAIR_OFFLINE'}, 240000);
        if (!await checkOffline()) throw new Error('incomplete cache');
      }
      if (navigator.storage?.persist) navigator.storage.persist().catch(() => {});
    } catch {
      status.textContent = 'O download não terminou. Confira a conexão e o espaço livre, mantenha a página aberta e tente novamente.';
      download.textContent = 'Tentar download novamente';
    } finally { download.disabled = false; }
  };
})();
