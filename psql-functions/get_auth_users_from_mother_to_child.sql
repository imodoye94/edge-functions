-- LIVES EXCLUSIVELY ON MOTHER VM, in the public schema and is calld from child
CREATE OR REPLACE FUNCTION public.get_auth_users_from_mother_to_child(
  _site_id uuid
  _last_synced_at timestamptz
)
RETURNS TABLE (
  instance_id                uuid,
  id                         uuid,
  aud                        varchar,
  role                       varchar,
  email                      varchar,
  encrypted_password         varchar,
  email_confirmed_at         timestamptz,
  invited_at                 timestamptz,
  confirmation_token         varchar,
  confirmation_sent_at       timestamptz,
  recovery_token             varchar,
  recovery_sent_at           timestamptz,
  email_change_token_new     varchar,
  email_change               varchar,
  email_change_sent_at       timestamptz,
  last_sign_in_at            timestamptz,
  raw_app_meta_data          jsonb,
  raw_user_meta_data         jsonb,
  is_super_admin             boolean,
  created_at                 timestamptz,
  updated_at                 timestamptz,
  phone                      text,
  phone_confirmed_at         timestamptz,
  phone_change               text,
  phone_change_token         varchar,
  phone_change_sent_at       timestamptz,
  confirmed_at               timestamptz,
  email_change_token_current varchar,
  email_change_confirm_status smallint,
  banned_until               timestamptz,
  reauthentication_token     varchar,
  reauthentication_sent_at   timestamptz,
  is_sso_user                boolean,
  deleted_at                 timestamptz,
  is_anonymous               boolean
)
LANGUAGE sql
SECURITY INVOKER
AS $$
  SELECT
    a.instance_id,
    a.id,
    a.aud,
    a.role,
    a.email,
    a.encrypted_password,
    a.email_confirmed_at,
    a.invited_at,
    a.confirmation_token,
    a.confirmation_sent_at,
    a.recovery_token,
    a.recovery_sent_at,
    a.email_change_token_new,
    a.email_change,
    a.email_change_sent_at,
    a.last_sign_in_at,
    a.raw_app_meta_data,
    a.raw_user_meta_data,
    a.is_super_admin,
    a.created_at,
    a.updated_at,
    a.phone,
    a.phone_confirmed_at,
    a.phone_change,
    a.phone_change_token,
    a.phone_change_sent_at,
    a.confirmed_at,
    a.email_change_token_current,
    a.email_change_confirm_status,
    a.banned_until,
    a.reauthentication_token,
    a.reauthentication_sent_at,
    a.is_sso_user,
    a.deleted_at,
    a.is_anonymous
  FROM auth.users a
  JOIN public.users u
    ON u.id = a.id
  WHERE u.site_id = _site_id
    AND (
      a.created_at > (SELECT _last_synced_at FROM public.sites WHERE id = _site_id)
      OR
      a.updated_at > (SELECT _last_synced_at FROM public.sites WHERE id = _site_id)
    );
$$;
