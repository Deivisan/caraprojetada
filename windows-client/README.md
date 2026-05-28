# 🪟 Cliente Windows — Sistema de Projeções UFRB/CETENS

Métodos para configurar um servidor VNC no Windows e conectar ao projetor.

## Métodos disponíveis

| Método | Arquivo | Testado no Windows 11 | Testado no Windows 10 |
|--------|---------|-----------------------|-----------------------|
| **TightVNC (recomendado)** | `definitive-tightvnc.bat` | ✅ Sim | ❌ Não testado |
| **UltraVNC** | `quick_setup_ultravnc.ps1` | Parcial | ❌ Não testado |
| **Provisionamento completo** | `provisioning/install_caraprojetada.ps1` | ✅ Sim | ❌ Não testado |

---

## Método 1 — TightVNC (recomendado)

Instalação completa com um clique via `definitive-tightvnc.bat`.

### O que o script faz

1. **Auto-elevação** — reinicia como Administrador se necessário
2. **Limpeza profunda** — remove qualquer instalação anterior do TightVNC (processos, serviço, registro, firewall)
3. **Download** — baixa TightVNC Server 2.8.87 de mirrors oficiais
4. **Instalação silenciosa** — via MSI com senha `123456`, firewall liberado, serviço automático
5. **Configuração forçada** — escreve senha no registro, libera portas 5900/5800 no firewall
6. **Inicialização** — inicia o serviço e verifica se está rodando
7. **Verificação** — testa serviço, porta 5900, senha no registro, regra de firewall e conexão TCP local

### Como usar

```batch
# Executar como Administrador (o script faz auto-elevação)
definitive-tightvnc.bat
```

O script:
- Instala o TightVNC Server com senha **123456**
- Configura o serviço para iniciar automaticamente com o Windows
- Libera a porta **5900** no firewall do Windows
- Exibe relatório de verificação no final

### ⚠️ Notas

- Não testado no **Windows 10** — apenas Windows 11
- A senha fixa `123456` é exigida pelo sistema de projeção (compatibilidade com `xtightvncviewer` na box)
- Para alterar a senha futuramente: `TightVNC Server > Admin Properties > Password`

---

## Método 2 — UltraVNC (alternativa)

Script leve de uma linha para configurar o UltraVNC após instalação manual.

```powershell
# Instale o UltraVNC manualmente, depois:
quick_setup_ultravnc.ps1
```

---

## Provisionamento automático (ISO personalizada)

Para deploy em massa, use os scripts em `provisioning/`:

- `install_caraprojetada.ps1` — instala e configura tudo
- `ultravnc_1822_setup.ps1` — setup específico do UltraVNC 1.8.2.2
- `autounattend.xml` — resposta para instalação automatizada do Windows

---

## Compatibilidade

O servidor VNC (qualquer método) deve estar rodando no computador do usuário
para que o sistema de projeção consiga conectar. Após configurar:

1. Acesse `http://172.17.28.179/` no navegador
2. Faça login com seu **SIAPE** e senha institucional (AD/UFRB)
3. O sistema detecta automaticamente que você está no Windows
4. Clique em **Conectar Tela ao Projetor**

> 💡 O servidor VNC precisa estar **ativo** antes de clicar em Conectar.
> No TightVNC, o serviço `tvnserver` já inicia automaticamente com o Windows.
