import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { DataSource } from 'typeorm';
import { ROLES_KEY } from './roles.decorator';

/** Consulta los roles vigentes de PostgreSQL en cada solicitud protegida. */
@Injectable()
export class RolesGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly db: DataSource,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const requiredRoles = this.reflector.getAllAndOverride<string[]>(
      ROLES_KEY,
      [context.getHandler(), context.getClass()],
    );
    if (!requiredRoles?.length) return true;

    const request = context.switchToHttp().getRequest();
    const rows = (await this.db.query(
      `SELECT r.name AS rol
       FROM user_roles AS ur
       JOIN roles AS r ON r.id = ur.role_id
       WHERE ur.user_id = $1
         AND r.status = true
         AND r.deleted_at IS NULL`,
      [request.user.sub],
    )) as Array<{ rol: string }>;

    if (!requiredRoles.some((required) => rows.some((row) => row.rol === required))) {
      throw new ForbiddenException('Permiso insuficiente');
    }
    return true;
  }
}
