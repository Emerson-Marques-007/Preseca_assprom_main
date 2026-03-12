// ============================================
// CONFIGURAÇÃO DO SUPABASE
// ============================================
// INSTRUÇÕES:
// 1. Crie um projeto em https://supabase.com
// 2. Copie a URL e a ANON KEY do seu projeto
// 3. Cole abaixo nos campos correspondentes
// ============================================

const RUNTIME_CONFIG = window.__APP_CONFIG__ || {};

const SUPABASE_URL = (RUNTIME_CONFIG.SUPABASE_URL || 'https://gsbdimmbokkzhqkehenv.supabase.co').trim();
const SUPABASE_ANON_KEY = (RUNTIME_CONFIG.SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdzYmRpbW1ib2tremhxa2VoZW52Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI3MzM3NDksImV4cCI6MjA4ODMwOTc0OX0.ejfgwZl1C6NsD0J2RhymVK6ajXNcG15khh8srpXGHs8').trim();

// URL publica usada para links do QR (celular)
// Exemplo: https://seu-projeto.netlify.app
const PUBLIC_BASE_URL = (RUNTIME_CONFIG.PUBLIC_BASE_URL || 'https://seu-projeto.netlify.app').trim();

function resolveBaseUrl() {
  const origemAtual = window.location.origin;
  const valor = (PUBLIC_BASE_URL || '').trim();
  if (!valor) return origemAtual;

  const semBarraFinal = valor.replace(/\/+$/, '');
  return semBarraFinal;
}

// Configurações do sistema
const CONFIG = {
  // Tolerância de atraso em minutos
  TOLERANCIA_ATRASO_MIN: Number(RUNTIME_CONFIG.TOLERANCIA_ATRASO_MIN || 10),

  // Tempo de validade do QR Code em minutos
  QR_VALIDADE_MIN: Number(RUNTIME_CONFIG.QR_VALIDADE_MIN || 5),

  // Raio padrão de geolocalização em metros
  RAIO_PADRAO_METROS: Number(RUNTIME_CONFIG.RAIO_PADRAO_METROS || 50),

  // Precisão mínima do GPS em metros
  GPS_PRECISAO_MIN: Number(RUNTIME_CONFIG.GPS_PRECISAO_MIN || 100),

  // Nome do app
  APP_NAME: RUNTIME_CONFIG.APP_NAME || 'Presença Digital',

  // Versão
  VERSION: RUNTIME_CONFIG.VERSION || '1.0.0',

  // URL base do site (para gerar QR codes)
  // Configure PUBLIC_BASE_URL acima para evitar QR com localhost
  BASE_URL: resolveBaseUrl(),

  // ID da planilha Google Sheets (para sincronização)
  GOOGLE_SHEET_ID: RUNTIME_CONFIG.GOOGLE_SHEET_ID || '',

  // Nome da Edge Function de integração com Google Sheets
  GOOGLE_SHEETS_FUNCTION: RUNTIME_CONFIG.GOOGLE_SHEETS_FUNCTION || 'google-sheets-sync',
};

// Inicializar Supabase Client
const { createClient } = supabase;
const supabaseClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

if (!window.__APP_CONFIG__) {
  console.warn('Runtime config não encontrado. Considere injetar window.__APP_CONFIG__ no deploy.');
}

// Exportar para uso global
window.supabaseClient = supabaseClient;
window.CONFIG = CONFIG;
