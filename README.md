# SmashRank

Sistema completo de gerenciamento de ranking de esportes de raquete, com sistema de desafios automatizado, reserva de quadras, gestão de clubes e painel administrativo.

---

## Visão Geral

O SmashRank permite que clubes de tênis (e outros esportes de raquete) gerenciem rankings internos baseados em desafios entre jogadores. O sistema aplica automaticamente 11 regras de negócio, controla penalizações, e fornece interfaces para jogadores e administradores.

### Componentes do Projeto

| Componente | Diretório | Tecnologia | Descrição |
|---|---|---|---|
| **App Mobile/Web** | `lib/` | Flutter / Dart | App principal para jogadores |
| **Painel Admin** | `admin/` | Next.js 16 / React 19 / TypeScript | Dashboard administrativo |
| **Landing Page** | `landing-page/` | HTML / CSS / JS puro | Página de marketing |
| **Backend** | `supabase/` | PostgreSQL / Supabase | Banco, auth, storage, realtime |
| **Cron Jobs** | `vercel-crons/` | Node.js / Vercel | Automações de penalização |

---

## Stack Tecnológica

### App Flutter

| Camada | Tecnologia |
|---|---|
| Framework | Flutter 3.38+ / Dart 3.10+ |
| Arquitetura | MVVM feature-first |
| State Management | Riverpod 2.x (manual, sem code generation) |
| Navegação | GoRouter com auth guard e nested routes |
| Auth | Email/Senha + Google Sign-In + Apple Sign-In |
| Realtime | Supabase Realtime (ranking, desafios) |
| Push Notifications | Firebase Cloud Messaging |
| Deep Linking | `smashrank://` (custom scheme) + universal links |

### Painel Admin (Next.js)

| Camada | Tecnologia |
|---|---|
| Framework | Next.js 16.1.6 / React 19.2.3 |
| Linguagem | TypeScript |
| Estilização | Tailwind CSS 4 |
| Gráficos | Recharts |
| Ícones | Lucide React |
| Backend | Supabase SSR |

### Backend (Supabase)

| Recurso | Uso |
|---|---|
| PostgreSQL | 11+ tabelas, 9+ RPCs, RLS em todas as tabelas |
| Auth (GoTrue) | Email, Google, Apple |
| Storage | Buckets `avatars` (público) e `receipts` (privado) |
| Realtime | Tabelas `players`, `challenges`, `ranking_history` |
| Edge Functions | Push notifications |

---

## Regras de Negócio

O sistema aplica automaticamente 11 regras para garantir competitividade e justiça no ranking:

| # | Regra | Detalhes |
|---|---|---|
| 1 | Desafio limitado | Máximo 2 posições acima no ranking |
| 2 | Cooldown do desafiante | 48h após resultado |
| 3 | Proteção do desafiado | 24h após ser desafiado |
| 4 | Prazo para jogar | 7 dias após agendar (+2 dias por chuva) |
| 5 | Prazo para responder | 48h (senão WO automático) |
| 6 | Desafio único | 1 desafio ativo por vez por jogador |
| 7 | Desafiante vence | Toma a posição do desafiado; desafiado desce 1 |
| 8 | Desafiado vence | Ninguém muda de posição |
| 9 | Ambulância | -3 posições imediato, 10 dias protegido, depois -1/dia |
| 10 | Inadimplência | 15+ dias: -10 posições + bloqueio de desafios |
| 11 | Inatividade mensal | -1 posição se nenhum desafio no mês |

---

## Arquitetura do App Flutter

```
lib/
├── main.dart                        # Entry point (Firebase + Supabase + Riverpod)
├── app.dart                         # MaterialApp.router (GoRouter + Theme + i18n pt-BR)
│
├── core/
│   ├── constants/
│   │   ├── app_constants.dart       # Constantes das regras de negócio
│   │   ├── route_names.dart         # Nomes de todas as rotas
│   │   └── supabase_constants.dart  # Nomes de tabelas e RPCs
│   ├── errors/
│   │   ├── app_exception.dart       # Hierarquia de exceções
│   │   └── error_handler.dart       # Mapeia erros Supabase → AppException
│   ├── extensions/                  # Extensions (BuildContext, datas)
│   ├── router/
│   │   └── app_router.dart          # GoRouter + auth redirect + bottom nav shell
│   ├── theme/
│   │   ├── app_colors.dart          # Paleta (forest green + gold)
│   │   ├── app_text_styles.dart     # Tipografia
│   │   └── app_theme.dart           # ThemeData Material 3
│   └── utils/                       # Snackbars, validadores
│
├── services/
│   ├── auth_service.dart            # Login, signup, social, reset
│   ├── storage_service.dart         # Upload avatar/recibos
│   ├── supabase_service.dart        # Providers do SupabaseClient
│   └── push_notification_service.dart # FCM
│
├── shared/
│   ├── models/                      # 14+ models com fromJson/toJson/copyWith
│   │   ├── enums.dart               # PlayerStatus, ChallengeStatus, etc.
│   │   ├── player_model.dart        # 25+ campos
│   │   ├── challenge_model.dart     # Joins, computed properties
│   │   ├── match_model.dart         # SetScore, scoreDisplay
│   │   ├── club_model.dart          # Multi-club support
│   │   └── ...
│   ├── providers/                   # Auth state, current player
│   └── widgets/                     # AppScaffold, FloatingNavBar, GradientButton
│
└── features/
    ├── auth/                        # Login, registro, recuperação de senha
    ├── ranking/                     # Lista realtime, histórico, gráficos
    ├── challenges/                  # Criar, propor datas, registrar resultado, H2H
    ├── courts/                      # Quadras, agenda, reservas
    ├── clubs/                       # Criar, ingressar, gerenciar clubes
    ├── profile/                     # Perfil, edição, perfil público
    ├── notifications/               # Lista, badge, mark as read
    └── admin/                       # Dashboard, jogadores, ambulâncias, esportes
```

Cada feature segue o padrão MVVM:
```
feature/
├── data/
│   └── feature_repository.dart      # Acesso a dados (Supabase)
├── view/
│   ├── feature_screen.dart          # Tela principal
│   └── widgets/                     # Componentes específicos
└── viewmodel/
    └── feature_viewmodel.dart       # Lógica de estado (Riverpod)
```

---

## Banco de Dados

### Tabelas Principais

| Tabela | Descrição |
|---|---|
| `players` | Jogadores com auth_id, ranking, cooldowns, ambulância, mensalidade |
| `ranking_history` | Histórico de todas as alterações de posição |
| `challenges` | Desafios com lifecycle completo |
| `matches` | Resultados com placar em JSONB (set a set) |
| `ambulances` | Controle de ambulâncias ativas e penalizações |
| `courts` | Quadras disponíveis |
| `court_slots` | Slots fixos por dia da semana/hora |
| `court_reservations` | Reservas específicas por data |
| `notifications` | Notificações in-app (14 tipos) |
| `monthly_fees` | Mensalidades |
| `clubs` | Clubes com membros e configurações |

### Migrations

31 migrations em `supabase/migrations/`, incluindo:

- `001` — Schema inicial (tabelas, enums, indexes)
- `002` — RLS policies em todas as tabelas
- `003` — 9 funções de lógica de negócio
- `004` — Seed data
- `005` — Sistema de notificações
- `006` — Multi-club support
- `008` — Multi-sport support
- `009` — Regras por esporte
- `023` — Pending result flow
- `026` — Ranking opt-in
- `030` — Regra de rematch
- `031` — FCM tokens

O arquivo `supabase/full_setup.sql` contém o SQL consolidado.

### Funções PostgreSQL (RPCs)

| Função | Descrição |
|---|---|
| `create_challenge()` | Valida regras + cria desafio + notifica |
| `swap_ranking_after_challenge()` | Troca posições quando desafiante vence |
| `activate_ambulance()` | -3 posições + proteção 10 dias |
| `deactivate_ambulance()` | Desativa ambulância |
| `apply_ambulance_daily_penalties()` | -1 posição/dia após proteção (cron) |
| `apply_overdue_penalties()` | -10 posições por inadimplência (cron) |
| `apply_monthly_inactivity_penalties()` | -1 posição por inatividade (cron) |
| `expire_pending_challenges()` | WO automático após 48h sem resposta (cron) |
| `validate_challenge_creation()` | Valida todas as regras de negócio |

---

## Cron Jobs (Vercel)

Automações hospedadas no Vercel que chamam RPCs do Supabase:

| Job | Schedule | Descrição |
|---|---|---|
| `expire-challenges` | A cada hora | WO automático em desafios sem resposta há 48h |
| `daily-penalties` | Diário às 3h | Penalização ambulância + inadimplência |
| `monthly-penalties` | Dia 1 às 4h | Penalização por inatividade mensal |

Protegidos por `CRON_SECRET` via Bearer token.

---

## Decisões Técnicas

- **Sem code generation**: `build_runner`/`freezed`/`riverpod_generator` removidos por incompatibilidade. Todos os providers e models são manuais.
- **API-first**: Toda lógica de negócio crítica está em funções PostgreSQL `SECURITY DEFINER` para garantir atomicidade e consistência.
- **RLS (Row Level Security)**: Todas as tabelas possuem policies de segurança.
- **Realtime**: Supabase Realtime para atualizações ao vivo do ranking e desafios.
- **Multi-tenant**: Suporte a múltiplos clubes e esportes por clube.

---

## Setup Local

### Pré-requisitos

- Flutter 3.38+ / Dart 3.10+
- Node.js 18+ (para admin e cron jobs)
- Conta no [Supabase](https://supabase.com)

### 1. App Flutter

```bash
# Copiar variáveis de ambiente
cp .env.example .env
# Editar .env com suas credenciais Supabase

# Instalar dependências
flutter pub get

# Rodar
flutter run
```

### 2. Banco de Dados (Supabase)

1. Crie um projeto no [Supabase Dashboard](https://app.supabase.com)
2. Execute `supabase/full_setup.sql` no SQL Editor
3. Configure Auth providers: **Email/Senha**, **Google**, **Apple**
4. Crie os buckets de Storage:
   - `avatars` (público)
   - `receipts` (privado)
5. Ative Realtime nas tabelas: `players`, `challenges`, `ranking_history`

### 3. Painel Admin

```bash
cd admin
npm install
cp .env.example .env.local
# Editar .env.local com credenciais Supabase
npm run dev
```

### 4. Cron Jobs

```bash
cd vercel-crons
npm install
# Deploy no Vercel com as variáveis:
#   SUPABASE_URL
#   SUPABASE_SERVICE_ROLE_KEY
#   CRON_SECRET
```

---

## Variáveis de Ambiente

### App Flutter (`.env`)

```
SUPABASE_URL=https://YOUR_PROJECT_ID.supabase.co
SUPABASE_ANON_KEY=YOUR_ANON_KEY_HERE
```

### Painel Admin (`.env.local`)

```
NEXT_PUBLIC_SUPABASE_URL=https://YOUR_PROJECT_ID.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=YOUR_ANON_KEY_HERE
SUPABASE_SERVICE_ROLE_KEY=YOUR_SERVICE_ROLE_KEY
```

### Cron Jobs (Vercel Environment)

```
SUPABASE_URL=https://YOUR_PROJECT_ID.supabase.co
SUPABASE_SERVICE_ROLE_KEY=YOUR_SERVICE_ROLE_KEY
CRON_SECRET=YOUR_SECRET_TOKEN
```

---

## Dependências Principais

### Flutter

| Pacote | Uso |
|---|---|
| `flutter_riverpod` | State management |
| `supabase_flutter` | Backend (DB, Auth, Storage, Realtime) |
| `go_router` | Navegação declarativa com auth guard |
| `fl_chart` | Gráficos de evolução do ranking |
| `table_calendar` | Calendário de reservas |
| `cached_network_image` | Cache de avatares |
| `google_sign_in` | Login com Google |
| `sign_in_with_apple` | Login com Apple |
| `firebase_core` / `firebase_messaging` | Push notifications |
| `app_links` | Deep linking |
| `image_picker` / `image_cropper` | Upload e edição de fotos |
| `flutter_dotenv` | Variáveis de ambiente |
| `intl` | Formatação de datas (pt-BR) |

### Admin (Next.js)

| Pacote | Uso |
|---|---|
| `@supabase/ssr` / `@supabase/supabase-js` | Backend |
| `recharts` | Gráficos e analytics |
| `lucide-react` | Ícones |
| `tailwindcss` | Estilização |

---

## Rotas do App

### Autenticação
- `/auth/login` — Login (email/senha + social)
- `/auth/register` — Cadastro
- `/auth/forgot-password` — Recuperação de senha

### Navegação Principal (bottom nav)
- `/ranking` — Lista de ranking (realtime)
  - `/ranking/history/:playerId` — Histórico do jogador
- `/challenges` — Desafios (ativos + histórico)
  - `/challenges/create` — Criar desafio
  - `/challenges/:id` — Detalhe do desafio
  - `/challenges/:id/record-result` — Registrar resultado
  - `/challenges/:id/h2h` — Head-to-Head
- `/courts` — Quadras
  - `/courts/my-reservations` — Minhas reservas
  - `/courts/:id/schedule` — Agenda da quadra
- `/notifications` — Notificações
- `/profile` — Perfil

### Rotas Standalone
- `/profile/edit` — Editar perfil
- `/clubs/create` — Criar clube
- `/clubs/join` — Ingressar em clube
- `/clubs/:id/manage` — Gerenciar clube
- `/players/:id` — Perfil público
- `/admin` — Painel admin

---

## Identidade Visual

| Elemento | Valor |
|---|---|
| Cor primária | Forest Green `#1B4332` (inspiração Wimbledon) |
| Cor secundária | Champagne Gold `#C9A84C` |
| Background | `#FAF8F5` (off-white quente) |
| Ranking 1° | Ouro |
| Ranking 2° | Prata |
| Ranking 3° | Bronze |
| Ambulância | Vermelho `#C0392B` |
| Design system | Material 3 |
| Fontes | Google Fonts (Inter + Space Grotesk na landing) |

---

## Pendências Conhecidas

- [ ] **Gestão de Mensalidades (Admin)** — card existe no dashboard mas sem tela implementada
- [ ] **Admin CRUD de Quadras/Slots** — gerenciamento de quadras pelo admin ainda não existe
- [ ] **Google Sign-In** — `webClientId` ainda é placeholder (`YOUR_GOOGLE_WEB_CLIENT_ID`)
- [ ] **Push Notifications nativas** — FCM funciona para web, mas Android/iOS ainda não estão configurados

## Roadmap

- [ ] Integração WhatsApp Business API (via N8N)
- [ ] Push notifications nativas (Android/iOS)
- [ ] Sistema de torneios
- [ ] Estatísticas avançadas de jogadores
