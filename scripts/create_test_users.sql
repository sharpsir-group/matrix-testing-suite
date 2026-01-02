-- Create Test Users for Matrix Testing Suite
-- Run this via Supabase SQL Editor or MCP

-- Create manager.test@sharpsir.group (admin)
INSERT INTO auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  created_at,
  updated_at,
  raw_app_meta_data,
  raw_user_meta_data,
  is_super_admin,
  confirmation_token,
  recovery_token
) VALUES (
  '00000000-0000-0000-0000-000000000000',
  gen_random_uuid(),
  'authenticated',
  'authenticated',
  'manager.test@sharpsir.group',
  crypt('TestPass123!', gen_salt('bf')),
  NOW(),
  NOW(),
  NOW(),
  '{"provider":"email","providers":["email"]}',
  '{"full_name":"Manager Test","member_type":"OfficeManager"}',
  false,
  '',
  ''
) ON CONFLICT (email) DO UPDATE SET
  encrypted_password = crypt('TestPass123!', gen_salt('bf')),
  email_confirmed_at = NOW(),
  raw_user_meta_data = '{"full_name":"Manager Test","member_type":"OfficeManager"}';

-- Create broker1.test@sharpsir.group
INSERT INTO auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  created_at,
  updated_at,
  raw_app_meta_data,
  raw_user_meta_data,
  is_super_admin,
  confirmation_token,
  recovery_token
) VALUES (
  '00000000-0000-0000-0000-000000000000',
  gen_random_uuid(),
  'authenticated',
  'authenticated',
  'broker1.test@sharpsir.group',
  crypt('TestPass123!', gen_salt('bf')),
  NOW(),
  NOW(),
  NOW(),
  '{"provider":"email","providers":["email"]}',
  '{"full_name":"Broker1 Test","member_type":"Broker"}',
  false,
  '',
  ''
) ON CONFLICT (email) DO UPDATE SET
  encrypted_password = crypt('TestPass123!', gen_salt('bf')),
  email_confirmed_at = NOW(),
  raw_user_meta_data = '{"full_name":"Broker1 Test","member_type":"Broker"}';

-- Create broker2.test@sharpsir.group
INSERT INTO auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  created_at,
  updated_at,
  raw_app_meta_data,
  raw_user_meta_data,
  is_super_admin,
  confirmation_token,
  recovery_token
) VALUES (
  '00000000-0000-0000-0000-000000000000',
  gen_random_uuid(),
  'authenticated',
  'authenticated',
  'broker2.test@sharpsir.group',
  crypt('TestPass123!', gen_salt('bf')),
  NOW(),
  NOW(),
  NOW(),
  '{"provider":"email","providers":["email"]}',
  '{"full_name":"Broker2 Test","member_type":"Broker"}',
  false,
  '',
  ''
) ON CONFLICT (email) DO UPDATE SET
  encrypted_password = crypt('TestPass123!', gen_salt('bf')),
  email_confirmed_at = NOW(),
  raw_user_meta_data = '{"full_name":"Broker2 Test","member_type":"Broker"}';

-- Grant admin permission to manager.test@sharpsir.group
INSERT INTO sso_user_permissions (user_id, permission_type, resource, granted_at)
SELECT id, 'admin', 'all', NOW()
FROM auth.users
WHERE email = 'manager.test@sharpsir.group'
ON CONFLICT DO NOTHING;

