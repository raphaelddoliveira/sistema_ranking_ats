-- ============================================================
-- Feature: SuperAdmin role
-- Role separada de admin de clube para acesso ao painel admin
-- ============================================================

-- Adicionar 'superadmin' ao enum player_role
ALTER TYPE player_role ADD VALUE IF NOT EXISTS 'superadmin';
