-- ============================================================
-- Atualizar is_admin() para checar superadmin
-- (separado da 028 porque enum novo precisa ser commitado antes)
-- ============================================================

CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM players WHERE auth_id = auth.uid() AND role = 'superadmin'
  );
$$ LANGUAGE sql SECURITY DEFINER;
