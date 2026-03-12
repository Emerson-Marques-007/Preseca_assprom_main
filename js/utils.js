// ============================================
// UTILITÁRIOS GLOBAIS
// ============================================

const Utils = {
  // --- Toast Notifications ---
  showToast(message, type = 'info', duration = 4000) {
    let container = document.getElementById('toast-container');
    if (!container) {
      container = document.createElement('div');
      container.id = 'toast-container';
      container.className = 'toast-container';
      document.body.appendChild(container);
    }

    const toast = document.createElement('div');
    toast.className = `toast toast-${type}`;
    toast.innerHTML = `
      <span>${this.escapeHtml(message)}</span>
      <button onclick="this.parentElement.remove()" style="background:none;border:none;color:inherit;cursor:pointer;font-size:1.2rem;padding:0 0 0 0.5rem;">&times;</button>
    `;
    container.appendChild(toast);

    setTimeout(() => {
      if (toast.parentElement) toast.remove();
    }, duration);
  },

  // --- Modal ---
  showModal(title, bodyHtml, footerHtml = '') {
    this.closeModal();
    const overlay = document.createElement('div');
    overlay.className = 'modal-overlay';
    overlay.id = 'modal-overlay';
    overlay.onclick = (e) => {
      if (e.target === overlay) this.closeModal();
    };

    overlay.innerHTML = `
      <div class="modal">
        <div class="modal-header">
          <h3>${this.escapeHtml(title)}</h3>
          <button class="btn btn-ghost btn-icon" onclick="Utils.closeModal()">&times;</button>
        </div>
        <div class="modal-body">${bodyHtml}</div>
        ${footerHtml ? `<div class="modal-footer">${footerHtml}</div>` : ''}
      </div>
    `;

    document.body.appendChild(overlay);
    document.body.style.overflow = 'hidden';
  },

  closeModal() {
    const overlay = document.getElementById('modal-overlay');
    if (overlay) {
      overlay.remove();
      document.body.style.overflow = '';
    }
  },

  // --- Loading ---
  showLoading(message = 'Carregando...') {
    this.hideLoading();
    const overlay = document.createElement('div');
    overlay.className = 'loading-overlay';
    overlay.id = 'loading-overlay';
    overlay.innerHTML = `
      <div class="spinner"></div>
      <p class="text-secondary">${this.escapeHtml(message)}</p>
    `;
    document.body.appendChild(overlay);
  },

  hideLoading() {
    const el = document.getElementById('loading-overlay');
    if (el) el.remove();
  },

  // --- Formatação ---
  formatDate(dateStr) {
    const d = new Date(dateStr);
    return d.toLocaleDateString('pt-BR', {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric'
    });
  },

  formatTime(timeStr) {
    if (!timeStr) return '--:--';
    // Aceita HH:MM:SS ou HH:MM
    const parts = timeStr.split(':');
    return `${parts[0]}:${parts[1]}`;
  },

  formatDateTime(dateTimeStr) {
    const d = new Date(dateTimeStr);
    return d.toLocaleDateString('pt-BR', {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  },

  today() {
    return new Date().toISOString().split('T')[0];
  },

  now() {
    return new Date().toISOString();
  },

  currentTime() {
    const now = new Date();
    return `${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}:${String(now.getSeconds()).padStart(2, '0')}`;
  },

  getDiaSemana(date = new Date()) {
    return date.getDay(); // 0=Dom, 1=Seg, ..., 6=Sáb
  },

  getDiaSemanaLabel(num) {
    const dias = ['Domingo', 'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado'];
    return dias[num] || '';
  },

  // --- Cálculos de horário ---
  timeToMinutes(timeStr) {
    const [h, m] = timeStr.split(':').map(Number);
    return h * 60 + m;
  },

  minutesToTime(min) {
    const h = Math.floor(min / 60);
    const m = min % 60;
    return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}`;
  },

  calcularAtraso(horaInicio, horaRegistro) {
    const inicioMin = this.timeToMinutes(horaInicio);
    const registroMin = this.timeToMinutes(horaRegistro);
    const diff = registroMin - inicioMin;
    return Math.max(0, diff);
  },

  calcularStatusPresenca(horaInicio, horaRegistro) {
    const atraso = this.calcularAtraso(horaInicio, horaRegistro);
    if (atraso <= CONFIG.TOLERANCIA_ATRASO_MIN) {
      return { status: 'presente', minutos_atraso: 0 };
    }
    return { status: 'atrasado', minutos_atraso: atraso };
  },

  // --- Geolocalização ---
  calcularDistancia(lat1, lon1, lat2, lon2) {
    // Fórmula de Haversine
    const R = 6371000; // Raio da Terra em metros
    const dLat = this.toRad(lat2 - lat1);
    const dLon = this.toRad(lon2 - lon1);
    const a =
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(this.toRad(lat1)) * Math.cos(this.toRad(lat2)) *
      Math.sin(dLon / 2) * Math.sin(dLon / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c; // Distância em metros
  },

  toRad(deg) {
    return deg * (Math.PI / 180);
  },

  async obterLocalizacao() {
    return new Promise((resolve, reject) => {
      if (!navigator.geolocation) {
        reject(new Error('Geolocalização não suportada pelo navegador'));
        return;
      }

      navigator.geolocation.getCurrentPosition(
        (pos) => {
          resolve({
            latitude: pos.coords.latitude,
            longitude: pos.coords.longitude,
            precisao: pos.coords.accuracy
          });
        },
        (err) => {
          switch (err.code) {
            case err.PERMISSION_DENIED:
              reject(new Error('Permissão de localização negada. Ative o GPS e permita o acesso.'));
              break;
            case err.POSITION_UNAVAILABLE:
              reject(new Error('Localização indisponível. Verifique seu GPS.'));
              break;
            case err.TIMEOUT:
              reject(new Error('Tempo esgotado ao obter localização. Tente novamente.'));
              break;
            default:
              reject(new Error('Erro ao obter localização.'));
          }
        },
        {
          enableHighAccuracy: true,
          timeout: 15000,
          maximumAge: 30000
        }
      );
    });
  },

  validarLocalizacao(latAluno, lonAluno, latSala, lonSala, raioMetros) {
    const distancia = this.calcularDistancia(latAluno, lonAluno, latSala, lonSala);
    return {
      dentroDoRaio: distancia <= raioMetros,
      distancia: Math.round(distancia)
    };
  },

  // --- Segurança ---
  escapeHtml(str) {
    if (!str) return '';
    const div = document.createElement('div');
    div.textContent = str;
    return div.innerHTML;
  },

  gerarUUID() {
    return crypto.randomUUID ? crypto.randomUUID() :
      'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
        const r = Math.random() * 16 | 0;
        const v = c === 'x' ? r : (r & 0x3 | 0x8);
        return v.toString(16);
      });
  },

  // --- Navegação ---
  getBasePath() {
    const path = window.location.pathname;
    // Detecta se estamos em subpasta
    if (path.includes('/aluno/')) return '../';
    if (path.includes('/professor/')) return '../';
    return './';
  },

  redirect(url) {
    window.location.href = url;
  },

  getQueryParam(name) {
    return new URLSearchParams(window.location.search).get(name);
  },

  // --- Theme ---
  initTheme() {
    const saved = localStorage.getItem('theme');
    // Usa o tema salvo; sem escolha prévia, segue o tema do sistema
    if (saved) {
      document.documentElement.setAttribute('data-theme', saved);
    } else {
      const systemDark = window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
      document.documentElement.setAttribute('data-theme', systemDark ? 'dark' : 'light');
    }
  },

  toggleTheme() {
    const current = document.documentElement.getAttribute('data-theme');
    const next = current === 'dark' ? 'light' : 'dark';
    document.documentElement.setAttribute('data-theme', next);
    localStorage.setItem('theme', next);
  },

  // --- Debounce ---
  debounce(fn, delay = 300) {
    let timer;
    return (...args) => {
      clearTimeout(timer);
      timer = setTimeout(() => fn.apply(this, args), delay);
    };
  },

  // --- Iniciais do nome ---
  getIniciais(nome) {
    if (!nome) return '?';
    return nome.split(' ')
      .filter(p => p.length > 0)
      .slice(0, 2)
      .map(p => p[0].toUpperCase())
      .join('');
  }
};

// Inicializar tema ao carregar
Utils.initTheme();
