-- ============================================================
-- 018: Storage policies for 'clubs' bucket
-- ============================================================
-- Allows authenticated users to upload/update club images (logo, cover).
-- Anyone can read (bucket is public).
-- ============================================================

-- Public read
CREATE POLICY "clubs_public_read"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'clubs');

-- Authenticated users can upload
CREATE POLICY "clubs_authenticated_insert"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'clubs');

-- Authenticated users can update (upsert)
CREATE POLICY "clubs_authenticated_update"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (bucket_id = 'clubs');

-- Authenticated users can delete their uploads
CREATE POLICY "clubs_authenticated_delete"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (bucket_id = 'clubs');
