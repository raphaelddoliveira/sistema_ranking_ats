# Sistema de Ranking ATS 2026

Sistema completo de gerenciamento de ranking de tenis, com cadastro de jogadores, sistema de desafios com 11 regras automatizadas, reserva de quadras com slots fixos por hora, e painel administrativo.

---

## Stack Tecnologica

| Camada | Tecnologia |
|--------|-----------|
| **Frontend** | Flutter 3.38.6 / Dart 3.10.7 |
| **Arquitetura** | MVVM (Model-View-ViewModel) feature-first |
| **State Management** | Riverpod 2.x (manual, sem code generation) |
| **Backend** | Supabase (PostgreSQL + Auth + Realtime + Storage) |
| **Navegacao** | GoRouter com auth guard |
| **Auth** | Email/Senha + Google Sign-In + Apple Sign-In |
| **Automacoes (futuro)** | N8N + WhatsApp Business API |

---

## Decisoes Tecnicas

- **Sem code generation**: build_runner/freezed/riverpod_generator removidos por incompatibilidade com Dart 3.10.7. Todos os providers e models sao manuais.
- **API-first**: Toda a logica de negocio critica esta em funcoes PostgreSQL `SECURITY DEFINER` para garantir atomicidade e consistencia.
- **RLS (Row Level Security)**: Todas as tabelas possuem policies de seguranca.
- **Realtime**: Supabase Realtime para atualizacoes ao vivo do ranking e desafios.
- **Deep Linking**: Configurado para `atsranking://` (custom scheme) + universal links.

---

## Estrutura do Projeto

```
lib/
  main.dart                          # Entry point (ProviderScope + Supabase.initialize)
  app.dart                           # MaterialApp.router (GoRouter + Theme)

  core/
    constants/
      app_constants.dart             # Regras de negocio (cooldowns, penalizacoes, etc.)
      route_names.dart               # Nomes de todas as rotas
      supabase_constants.dart        # Nomes de tabelas e RPCs do Supabase
    errors/
      app_exception.dart             # Hierarquia de excecoes (Auth, Network, Database, etc.)
      error_handler.dart             # Mapeia erros Supabase -> AppException
    extensions/
      context_extensions.dart        # Extensions do BuildContext
      date_extensions.dart           # Formatacao de datas, timeAgo, countdown
    router/
      app_router.dart                # GoRouter com auth redirect + bottom nav shell
    theme/
      app_colors.dart                # Cores do app (tennis green, gold, status colors)
      app_text_styles.dart           # Estilos de texto
      app_theme.dart                 # ThemeData Material 3 (light + dark)
    utils/
      snackbar_utils.dart            # Helpers para exibir snackbars
      validators.dart                # Validadores de form (email, senha, telefone)

  services/
    auth_service.dart                # Wrapper do GoTrueClient (login, signup, social, reset)
    storage_service.dart             # Upload de avatar/recibos para Supabase Storage
    supabase_service.dart            # Providers do SupabaseClient, GoTrueClient, Storage

  shared/
    models/
      enums.dart                     # Enums espelhando o banco (PlayerStatus, ChallengeStatus, etc.)
      player_model.dart              # Model completo com fromJson/toJson/copyWith manual
    providers/
      auth_state_provider.dart       # StreamProvider do onAuthStateChange
      current_player_provider.dart   # FutureProvider do jogador logado
    widgets/
      app_scaffold.dart              # Bottom navigation (5 tabs: Ranking, Desafios, Quadras, Alertas, Perfil)

  features/
    auth/
      data/
        auth_repository.dart         # Auth + criacao automatica de player no signup
      view/
        login_screen.dart            # Login email/senha + social + links
        register_screen.dart         # Cadastro completo (nome, email, whatsapp, senha)
        forgot_password_screen.dart  # Reset de senha por email
        widgets/
          auth_form_field.dart       # TextFormField reutilizavel
          social_login_buttons.dart  # Botoes Google + Apple
      viewmodel/
        login_viewmodel.dart         # StateNotifier com login email + social
        register_viewmodel.dart      # StateNotifier com registro completo

    profile/
      data/
        player_repository.dart       # CRUD do perfil (getPlayer, getAllPlayers, update, avatar)
      view/
        profile_screen.dart          # Perfil com header, stats, info tiles, logout
        widgets/
          profile_header.dart        # Avatar + nome + nickname + email
          stats_card.dart            # Card com icone, valor e label
      viewmodel/
        profile_viewmodel.dart       # StateNotifier com updateProfile e updateAvatar

    ranking/                         # [FASE 3 - Pendente]
      data/
      view/
        ranking_screen.dart          # Placeholder
        widgets/
      viewmodel/

    challenges/                      # [FASE 4 - Pendente]
      data/
      view/
        challenges_screen.dart       # Placeholder
        widgets/
      viewmodel/

    courts/                          # [FASE 5 - Pendente]
      data/
      view/
        courts_screen.dart           # Placeholder
        widgets/
      viewmodel/

    notifications/                   # [FASE 6 - Pendente]
      data/
      view/
        notifications_screen.dart    # Placeholder
        widgets/
      viewmodel/

    admin/                           # [FASE 6 - Pendente]
      data/
      view/
        widgets/
      viewmodel/

supabase/
  migrations/
    001_initial_schema.sql           # 11 tabelas, 6 enums, indexes, triggers
    002_rls_policies.sql             # RLS em todas as tabelas + helper functions
    003_database_functions.sql       # 9 funcoes de logica de negocio
    004_seed_data.sql                # 3 quadras + slots horarios
  full_setup.sql                     # SQL consolidado (tudo acima em 1 arquivo)
```

---

## Banco de Dados (PostgreSQL via Supabase)

### Tabelas (11)

| Tabela | Descricao |
|--------|-----------|
| `players` | Jogadores com auth_id, ranking, cooldowns, ambulancia, mensalidade |
| `ranking_history` | Historico de todas as alteracoes de posicao |
| `challenges` | Desafios com lifecycle completo (pending -> scheduled -> completed/wo) |
| `matches` | Resultados com placar em JSONB (set a set) |
| `ambulances` | Controle de ambulancias ativas e penalizacoes diarias |
| `courts` | Quadras disponiveis |
| `court_slots` | Slots fixos por dia da semana/hora |
| `court_reservations` | Reservas especificas por data |
| `notifications` | Notificacoes in-app |
| `monthly_fees` | Mensalidades |
| `whatsapp_logs` | Logs para futura integracao N8N/WhatsApp |

### Funcoes PostgreSQL (9)

| Funcao | Descricao |
|--------|-----------|
| `swap_ranking_after_challenge()` | Troca posicoes quando desafiante vence |
| `activate_ambulance()` | Penaliza -3 posicoes, ativa protecao 10 dias |
| `deactivate_ambulance()` | Desativa ambulancia |
| `apply_ambulance_daily_penalties()` | -1 posicao/dia apos protecao (cron) |
| `apply_overdue_penalties()` | -10 posicoes por inadimplencia 15+ dias (cron) |
| `apply_monthly_inactivity_penalties()` | -1 posicao por inatividade mensal (cron) |
| `validate_challenge_creation()` | Valida TODAS as regras de negocio |
| `create_challenge()` | Valida + cria desafio + notifica |
| `expire_pending_challenges()` | WO automatico apos 48h sem resposta (cron) |

---

## Regras de Negocio (11 Regras)

1. **Desafio limitado a 2 posicoes acima** no ranking
2. **Cooldown de 48h** para o desafiante apos resultado
3. **Protecao de 24h** para o desafiado apos ser desafiado
4. **Prazo de 7 dias** para jogar apos agendar (com extensao de +2 dias por chuva)
5. **48h para responder** a um desafio (senao WO automatico)
6. **1 desafio ativo** por vez por jogador
7. **Desafiante vence**: toma a posicao do desafiado, desafiado desce 1
8. **Desafiado vence**: ninguem muda de posicao
9. **Ambulancia**: -3 posicoes imediato, 10 dias protegido, depois -1/dia
10. **Inadimplencia 15+ dias**: -10 posicoes e bloqueio de desafios
11. **Inatividade mensal**: -1 posicao se nao participou de nenhum desafio no mes

---

## O Que Ja Foi Implementado

### Fase 1 - Setup do Projeto + Banco de Dados (COMPLETA)
- [x] Projeto Flutter criado com todas as dependencias
- [x] Estrutura de pastas MVVM feature-first completa
- [x] 4 SQL migrations (schema, RLS, functions, seed)
- [x] SQL consolidado (`full_setup.sql`)
- [x] Infraestrutura core (theme Material 3, router, services, constants, errors, extensions, utils)
- [x] `flutter analyze` = 0 issues

### Fase 2 - Auth + Cadastro de Jogadores (COMPLETA)
- [x] PlayerModel com fromJson/toJson/copyWith manual (25+ campos)
- [x] AuthService (email, Google, Apple, reset password)
- [x] StorageService (upload avatar/recibos)
- [x] AuthRepository (auth + criacao automatica de player no signup/social login)
- [x] Auth state providers (StreamProvider + current player)
- [x] LoginViewModel + RegisterViewModel
- [x] ProfileViewModel (update profile, update avatar)
- [x] PlayerRepository (CRUD)
- [x] Tela de Login (email/senha + social + links)
- [x] Tela de Cadastro (nome, email, whatsapp, senha, confirmacao)
- [x] Tela de Recuperacao de Senha
- [x] Tela de Perfil (header, stats, info tiles, logout)
- [x] GoRouter com auth guard + bottom navigation shell
- [x] `flutter analyze` = 0 issues

### Fase 3 - Sistema de Ranking (PENDENTE)
- [ ] RankingRepository (getRanking, getRankingStream, getPlayerHistory)
- [ ] RankingListViewModel (StreamProvider com Realtime)
- [ ] RankingHistoryViewModel
- [ ] Tela de Ranking (lista com posicao, avatar, nome, W/L)
- [ ] Tela de Historico de Ranking (timeline + grafico fl_chart)
- [ ] Widgets: ranking_list_tile, ranking_position_change, ranking_chart

### Fase 4 - Sistema de Desafios (PENDENTE)
- [ ] ChallengeModel, MatchModel, AmbulanceModel
- [ ] ChallengeRepository (RPC calls, lifecycle)
- [ ] ViewModels (list, create, detail, record result)
- [ ] 6 telas (lista, criar, detalhe, propor datas, escolher data, registrar resultado)
- [ ] Sistema de ambulancia (admin)

### Fase 5 - Reserva de Quadra (PENDENTE)
- [ ] CourtModel, CourtSlotModel, ReservationModel
- [ ] CourtRepository
- [ ] ViewModels
- [ ] Telas (lista quadras, agenda com calendario, minhas reservas, admin CRUD)

### Fase 6 - Notificacoes + Admin + Polish (PENDENTE)
- [ ] Sistema de notificacoes in-app com Realtime
- [ ] Painel admin
- [ ] Deep linking completo
- [ ] Badge de notificacoes nao lidas

### Fase 7 - Automacoes (FUTURO)
- [ ] N8N crons para penalizacoes automaticas
- [ ] Integracao WhatsApp Business API

---

## Como Rodar

### Pre-requisitos
- Flutter 3.38+ / Dart 3.10+
- Conta no Supabase

### Setup
1. Clone o repositorio
2. Copie `.env.example` para `.env` e preencha com suas credenciais Supabase
3. Execute o `supabase/full_setup.sql` no SQL Editor do Supabase
4. Configure os providers de auth no Supabase Dashboard (Email, Google, Apple)
5. Crie os buckets de Storage: `avatars`, `receipts`
6. Ative Realtime nas tabelas `players`, `challenges`, `ranking_history`

```bash
flutter pub get
flutter run
```

### Configuracao do Supabase
- **Authentication**: Habilitar Email/Senha + Google + Apple
- **Storage**: Criar buckets `avatars` (public) e `receipts` (private)
- **Realtime**: Ativar nas tabelas `players`, `challenges`, `ranking_history`
- **Database**: Executar `full_setup.sql` no SQL Editor

---

## Dependencias Principais

| Pacote | Versao | Uso |
|--------|--------|-----|
| flutter_riverpod | ^2.6.1 | State management |
| supabase_flutter | ^2.8.0 | Backend (DB, Auth, Storage, Realtime) |
| go_router | ^14.8.1 | Navegacao declarativa com auth guard |
| fl_chart | ^0.70.2 | Graficos de ranking |
| table_calendar | ^3.2.0 | Calendario de reservas |
| cached_network_image | ^3.4.1 | Cache de avatares |
| google_sign_in | ^6.2.2 | Login com Google |
| sign_in_with_apple | ^6.1.3 | Login com Apple |
| app_links | ^6.3.3 | Deep linking |
| image_picker | ^1.1.2 | Upload de fotos |
| flutter_dotenv | ^5.2.1 | Variaveis de ambiente |
| intl | ^0.20.2 | Formatacao de datas |
