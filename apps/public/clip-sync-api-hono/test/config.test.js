import { fileURLToPath } from 'node:url';

import { describe, expect, it } from 'vitest';

import { loadConfig } from '../src/config.js';

const validEnvironment = {
  CLIP_SYNC_ENV: 'local',
  CLIP_SYNC_API_PORT: '4100',
  CLIP_SYNC_POSTGRES_URL: 'postgres://user:password@localhost:5400/clip_sync',
  CLIP_SYNC_MONGO_URL: 'mongodb://user:password@localhost:27017/clip_sync',
  CLIP_SYNC_JWT_SECRET: 'jwt-secret-that-is-at-least-32-characters',
  CLIP_SYNC_AUTH_CODE_PEPPER: 'code-pepper-that-is-at-least-32-characters',
  CLIP_SYNC_GOOGLE_CLIENT_IDS: 'one.apps.googleusercontent.com,two.apps.googleusercontent.com',
  CLIP_SYNC_SMTP_HOST: 'localhost',
  CLIP_SYNC_SMTP_PORT: '1025',
  CLIP_SYNC_SMTP_SECURE: 'false',
  CLIP_SYNC_SMTP_USER: '',
  CLIP_SYNC_SMTP_PASSWORD: '',
  CLIP_SYNC_EMAIL_FROM: 'no-reply@example.com',
  CLIP_SYNC_CORS_ORIGINS: '*',
};

describe('loadConfig', () => {
  it('parses required values and comma-separated client IDs', () => {
    const config = loadConfig(validEnvironment);

    expect(config.port).toBe(4100);
    expect(config.googleClientIds).toEqual([
      'one.apps.googleusercontent.com',
      'two.apps.googleusercontent.com',
    ]);
    expect(config.smtp.secure).toBe(false);
  });

  it('loads a Google client ID from a mounted OAuth configuration file', () => {
    const environment = {
      ...validEnvironment,
      CLIP_SYNC_GOOGLE_CLIENT_IDS: '',
      CLIP_SYNC_GOOGLE_OAUTH_CONFIG_PATH: fileURLToPath(
        new URL('fixtures/google-oauth.json', import.meta.url),
      ),
    };

    expect(loadConfig(environment).googleClientIds).toEqual([
      'file-client.apps.googleusercontent.com',
    ]);
  });

  it('requires Google client IDs or an OAuth configuration file', () => {
    expect(() =>
      loadConfig({
        ...validEnvironment,
        CLIP_SYNC_GOOGLE_CLIENT_IDS: '',
      }),
    ).toThrow('Google client IDs or a Google OAuth configuration file is required.');
  });

  it('fails when only one SMTP credential is provided', () => {
    expect(() => loadConfig({ ...validEnvironment, CLIP_SYNC_SMTP_USER: 'user' })).toThrow(
      'must be set together',
    );
  });

  it('fails when authentication secrets are reused', () => {
    expect(() =>
      loadConfig({
        ...validEnvironment,
        CLIP_SYNC_AUTH_CODE_PEPPER: validEnvironment.CLIP_SYNC_JWT_SECRET,
      }),
    ).toThrow('must be different');
  });

  it('rejects wildcard CORS in production', () => {
    expect(() => loadConfig({ ...validEnvironment, CLIP_SYNC_ENV: 'production' })).toThrow(
      'must be explicit',
    );
  });
});
