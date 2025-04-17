CREATE OR REPLACE FUNCTION public.create_storage_bucket(
  _organization_id uuid,
  _site_id         uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO storage.buckets (
    id,
    name,
    owner,
    owner_id,
    file_size_limit
  )
  VALUES (
    _site_id::text,          -- id
    _site_id::text,          -- name
    _organization_id,        -- owner (uuid)
    _organization_id::text,  -- owner_id (text)
    104857600                -- 100 MB
  )
  ON CONFLICT (id) DO UPDATE
    SET name             = EXCLUDED.name,
        owner            = EXCLUDED.owner,
        owner_id         = EXCLUDED.owner_id,
        file_size_limit  = EXCLUDED.file_size_limit,
        updated_at       = NOW();

  -- Note: created_at will only be set on the first insert (default now())
END;
$$;
