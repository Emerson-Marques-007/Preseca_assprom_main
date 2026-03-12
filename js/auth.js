// ============================================
// MÓDULO DE AUTENTICAÇÃO
// ============================================

const Auth = {
  // Cache do perfil atual
  _perfil: null,
  _session: null,

  // --- Regra de papel por domínio de email ---
  normalizarEmail(email = '') {
    return String(email || '').trim().toLowerCase();
  },

  inferirRolePorEmail(email = '') {
    const emailNormalizado = this.normalizarEmail(email);
    const dominio = emailNormalizado.split('@')[1] || '';
    return dominio === 'assprom.org.br' ? 'professor' : 'aluno';
  },

  // --- Cadastro ---
  async cadastrar(email, senha, nome, matricula) {
    try {
      const emailNormalizado = this.normalizarEmail(email);
      const role = this.inferirRolePorEmail(emailNormalizado);

      // 1. Verificar se matrícula já existe
      const { data: existente } = await supabaseClient
        .from('perfis')
        .select('id')
        .eq('matricula', matricula)
        .single();

      if (existente) {
        throw new Error('Esta matrícula já está cadastrada.');
      }

      // 2. Criar usuário no Supabase Auth
      const { data: authData, error: authError } = await supabaseClient.auth.signUp({
        email: emailNormalizado,
        password: senha,
        options: {
          data: {
            nome,
            matricula,
            role
          }
        }
      });

      if (authError) throw authError;

      // 3. Criar perfil na tabela perfis
      const { error: perfilError } = await supabaseClient
        .from('perfis')
        .insert({
          id: authData.user.id,
          nome,
          matricula,
          role,
          email: emailNormalizado
        });

      if (perfilError) throw perfilError;

      return { success: true, user: authData.user, role };
    } catch (error) {
      console.error('Erro no cadastro:', error);
      return { success: false, error: error.message };
    }
  },

  // --- Login ---
  async login(email, senha) {
    try {
      const { data, error } = await supabaseClient.auth.signInWithPassword({
        email,
        password: senha
      });

      if (error) throw error;

      this._session = data.session;
      return { success: true, session: data.session };
    } catch (error) {
      console.error('Erro no login:', error);
      let msg = error.message;
      if (msg.includes('Invalid login')) {
        msg = 'Email ou senha incorretos.';
      }
      return { success: false, error: msg };
    }
  },

  // --- Login por matrícula ---
  async loginPorMatricula(matricula, senha) {
    try {
      // Buscar email pela matrícula usando RPC (acessível sem autenticação)
      const { data, error: rpcError } = await supabaseClient
        .rpc('buscar_email_por_matricula', { p_matricula: matricula });

      if (rpcError || !data || data.length === 0) {
        throw new Error('Matrícula não encontrada.');
      }

      return await this.login(data[0].email, senha);
    } catch (error) {
      console.error('Erro no login por matrícula:', error);
      return { success: false, error: error.message };
    }
  },

  // --- Logout ---
  async logout() {
    await supabaseClient.auth.signOut();
    this._perfil = null;
    this._session = null;
    Utils.redirect(Utils.getBasePath() + 'index.html');
  },

  // --- Sessão atual ---
  async getSession() {
    if (this._session) return this._session;
    const { data: { session } } = await supabaseClient.auth.getSession();
    this._session = session;
    return session;
  },

  // --- Perfil do usuário logado ---
  async getPerfil() {
    if (this._perfil) return this._perfil;

    const session = await this.getSession();
    if (!session) return null;

    const { data, error } = await supabaseClient
      .from('perfis')
      .select('*')
      .eq('id', session.user.id)
      .single();

    if (error) {
      console.error('Erro ao buscar perfil:', error);
      return null;
    }

    this._perfil = data;
    return data;
  },

  // --- Verificar se está logado ---
  async isLogado() {
    const session = await this.getSession();
    return !!session;
  },

  // --- Verificar role ---
  async getRole() {
    const perfil = await this.getPerfil();
    return perfil ? perfil.role : null;
  },

  // --- Guard de autenticação ---
  // Redireciona para login se não estiver logado
  async requireAuth() {
    const logado = await this.isLogado();
    if (!logado) {
      Utils.redirect(Utils.getBasePath() + 'index.html');
      return false;
    }
    return true;
  },

  // --- Guard de role ---
  async requireRole(roleEsperado) {
    const autenticado = await this.requireAuth();
    if (!autenticado) return false;

    const role = await this.getRole();
    if (role !== roleEsperado) {
      Utils.showToast('Acesso não autorizado.', 'error');
      // Redirecionar para a página correta
      if (role === 'professor') {
        Utils.redirect(Utils.getBasePath() + 'professor/index.html');
      } else {
        Utils.redirect(Utils.getBasePath() + 'aluno/index.html');
      }
      return false;
    }
    return true;
  },

  // --- Renderizar navbar com dados do usuário ---
  async renderNavbar(containerId = 'navbar') {
    const perfil = await this.getPerfil();
    if (!perfil) return;

    const container = document.getElementById(containerId);
    if (!container) return;

    const iniciais = Utils.getIniciais(perfil.nome);
    const navUser = container.querySelector('.navbar-user');
    if (navUser) {
      navUser.innerHTML = `
        <span class="hidden-mobile">${Utils.escapeHtml(perfil.nome.split(' ')[0])}</span>
        <div class="navbar-avatar">${iniciais}</div>
      `;
    }
  },

  // --- Listener de mudança de auth ---
  onAuthChange(callback) {
    supabaseClient.auth.onAuthStateChange((event, session) => {
      this._session = session;
      this._perfil = null; // limpar cache
      callback(event, session);
    });
  }
};

window.Auth = Auth;
