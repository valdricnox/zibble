# ⚡ Zibble's Performance v2.0
> **Windows Optimization Toolkit — Professional Edition**

---

## 🚀 Acesso Rápido

Abra o **PowerShell como Administrador** e cole:
```powershell
irm https://raw.githubusercontent.com/SEU_USUARIO/zibble/main/zibble.ps1 | iex
```

Ou baixe e execute o `zibble.bat` — ele solicita admin automaticamente.

---

## ✨ O que há de novo na v2.0

| Feature | Descrição |
|---------|-----------|
| 📊 **Dashboard** | Tela de status em tempo real antes do menu |
| 🎯 **Presets** | Gamer Extremo, Trabalho, Mínimo Seguro, Suporte |
| 🔄 **Reversão** | Todos os módulos têm opção de reverter ao padrão |
| 📈 **Benchmark** | Mede antes/depois e mostra comparativo |
| 🛡️ **Modo Seguro** | Esconde tweaks de risco para uso em PCs de terceiros |
| 💾 **Config JSON** | Salva perfil e histórico em `%APPDATA%\Zibble\` |
| ⌨️ **Módulo KBM** | Teclado, mouse e USB como módulo dedicado |
| 🌐 **DNS Custom** | Cloudflare, Google, Quad9 ou DNS personalizado |
| 📄 **Relatório HTML** | Relatório visual completo com score de otimização |
| 🔄 **Auto-Update** | Verifica nova versão no GitHub automaticamente |
| 📦 **Instalador++** | Detecta apps já instalados, 4 categorias |
| 🔌 **Portas/Rede** | Diagnóstico completo com teste de velocidade |

---

## 📂 Módulos

| # | Módulo | Descrição |
|---|--------|-----------|
| 1 | ⚡ Performance | BCD, NTFS, Memória, MMCSS, HAGS, Latência |
| 2 | ⌨️ KBM | Mouse, Teclado, USB MSI Mode |
| 3 | 🖥️ GPU & Display | NVIDIA/AMD/iGPU auto-detectado, KBoost |
| 4 | 🌐 Rede | TCP/IP, NIC, DNS, IPv6, Delivery Opt |
| 5 | 🔇 Telemetria | Registry, Tasks, AutoLoggers, Serviços |
| 6 | 🧹 Debloat | Apps, Cortana, OneDrive, Serviços, Edge |
| 7 | 📦 Install | Steam, Discord, Chrome, Dev Tools via Winget |
| 8 | 🔧 Fixes | SFC, DISM, WU, Rede, Wi-Fi, Drivers |
| 9 | 🎯 Presets | Gamer / Work / Safe / Support |
| 10 | 🗂️ Extras | Painéis Windows, Limpeza, Relatório HTML |

---

## 🎯 Presets

**Gamer Extremo** — Para PCs de gaming dedicados. Aplica tudo: performance, GPU, KBM, rede, telemetria e debloat. Inclui benchmark antes/depois.

**Trabalho/Escritório** — Performance + privacidade sem comprometer estabilidade. Mantém Defender.

**Mínimo Seguro** — Só tweaks sem risco. Ideal para PCs de clientes ou ambientes corporativos.

**Suporte Técnico** — Diagnóstico + fixes + limpeza. Perfeito para técnicos em campo.

---

## 📁 Arquivos

```
zibble/
├── zibble.ps1       — Script principal (PowerShell)
├── zibble.bat       — Launcher com auto-elevação
├── version.txt      — Versão atual (para auto-update)
└── README.md        — Esta documentação
```

**Dados gerados pelo Zibble:**
```
%APPDATA%\Zibble\
├── zibble_config.json   — Perfil e histórico do usuário
└── zibble_log.txt       — Log completo de todas as sessões

%USERPROFILE%\Desktop\
├── zibble_report.html   — Relatório visual
├── zibble_bateria.html  — Relatório de bateria
└── zibble_diagnostico.txt
```

---

## ⚠️ Avisos Importantes

- **Sempre crie um ponto de restauração antes** — o Zibble faz isso automaticamente antes de módulos destrutivos
- Módulos com risco (Defender, Mitigações, BCD) exigem confirmação dupla
- O **Modo Seguro** (`[M]` no menu) esconde tweaks perigosos — use em PCs de clientes
- Testado em **Windows 10 (21H2+)** e **Windows 11**
- Requer **PowerShell 5.1+** e **privilégios de Administrador**

---

## 🔧 Requisitos

- Windows 10 (Build 19041+) ou Windows 11
- PowerShell 5.1 ou superior
- Conta de Administrador
- Winget (para instalação de apps) — já incluso no Win11 e Win10 atualizado

---

## 📋 Roadmap

- [ ] Interface TUI com navegação por setas
- [ ] Exportar/importar perfis de configuração
- [ ] Suporte a múltiplos usuários/máquinas
- [ ] Integração com MSI Afterburner (overclock)
- [ ] Scanner de drivers desatualizados
- [ ] Modo silencioso (sem interface, via parâmetros)

---

*Criado por Zibble — Inspirado em Chris Titus WinUtil, Ancel's Performance Batch, João Fernandes IT Tools*
