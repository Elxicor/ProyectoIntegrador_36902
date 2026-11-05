import { MigrationInterface, QueryRunner } from 'typeorm';

/** Esquema inicial de AUTH: usuarios, roles y asignación N:M. */
export class InitialIdentity1793740000000 implements MigrationInterface {
  name = 'InitialIdentity1793740000000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE users (
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        cedula varchar(10) NOT NULL,
        nombres varchar(100) NOT NULL,
        apellidos varchar(100) NOT NULL,
        fecha_nacimiento date NOT NULL,
        username varchar(50) NOT NULL,
        email varchar(150) NOT NULL,
        password_hash varchar(255) NOT NULL,
        token_version integer NOT NULL DEFAULT 0,
        status boolean NOT NULL DEFAULT true,
        version integer NOT NULL DEFAULT 1,
        created_at timestamp NOT NULL DEFAULT now(),
        updated_at timestamp NOT NULL DEFAULT now(),
        deleted_at timestamp,
        CONSTRAINT CHK_users_cedula CHECK (cedula ~ '^[0-9]{10}$'),
        CONSTRAINT UQ_users_cedula UNIQUE (cedula),
        CONSTRAINT UQ_users_username UNIQUE (username),
        CONSTRAINT UQ_users_email UNIQUE (email)
      );
      CREATE TABLE roles (
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        name varchar(50) NOT NULL,
        description varchar(255) NOT NULL DEFAULT '',
        status boolean NOT NULL DEFAULT true,
        version integer NOT NULL DEFAULT 1,
        created_at timestamp NOT NULL DEFAULT now(),
        updated_at timestamp NOT NULL DEFAULT now(),
        deleted_at timestamp,
        CONSTRAINT UQ_roles_rol UNIQUE (name)
      );
      CREATE TABLE user_roles (
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        role_id uuid NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
        assigned_at timestamp NOT NULL DEFAULT now(),
        CONSTRAINT UQ_user_roles_user_role UNIQUE (user_id, role_id)
      );
      CREATE INDEX IDX_user_roles_user ON user_roles(user_id);
      CREATE INDEX IDX_user_roles_role ON user_roles(role_id);
    `);
  }

  async down(): Promise<void> {
    throw new Error('No se destruyen datos de identidad mediante rollback automático.');
  }
}
