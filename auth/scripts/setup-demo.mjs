// Inicializacion idempotente de usuarios y roles. Ejecutar dentro del contenedor AUTH.
const origin = `https://localhost:${process.env.PORT || 3001}`;
const password = process.env.SEED_ADMIN_PASSWORD || 'ChangeMe-Admin-2026!';
async function request(route, method = 'GET', token, data) {
  const response = await fetch(`${origin}${route}`, {
    method,
    headers: {
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(data ? { 'Content-Type': 'application/json' } : {}),
    },
    ...(data ? { body: JSON.stringify(data) } : {}),
  });
  const raw = await response.text();
  let body;
  try { body = raw ? JSON.parse(raw) : {}; } catch { body = { message: raw }; }
  if (!response.ok) {
    const error = new Error(`${method} ${route}: HTTP ${response.status} ${JSON.stringify(body)}`);
    error.statusCode = response.status;
    throw error;
  }
  return body;
}
const login = await request('/api/auth/login', 'POST', null, { identity: 'admin', password });
if (!login.access_token) throw new Error('AUTH no devolvió un JWT para ADMIN');
const token = login.access_token;
const roles = await request('/api/roles', 'GET', token);
let users = await request('/api/users', 'GET', token);
const definitions = [
  { username:'analyst', cedula:'1111111111', nombres:'Ana', apellidos:'Analista', email:'analyst@example.local', password:'Analyst-Pass-2026!', roles:['ANALYST','USER'] },
  { username:'user', cedula:'2222222222', nombres:'Una', apellidos:'Usuario', email:'user@example.local', password:'User-Secure-2026!', roles:['USER'] },
];
for (const item of definitions) {
  let existing = users.find(u => u.username === item.username);
  if (!existing) {
    existing = await request('/api/users', 'POST', token, {
      cedula:item.cedula, nombres:item.nombres, apellidos:item.apellidos,
      fechaNacimiento:'1995-01-01', username:item.username, email:item.email,
      password:item.password,
    });
    users = [...users, existing];
  }
  for (const name of item.roles) {
    const role = roles.find(r => r.rol === name);
    if (!role) throw new Error(`No existe el rol ${name}`);
    try { await request('/api/user-roles', 'POST', token, { userId:existing.id, roleId:role.id }); }
    catch (err) { if (err.statusCode !== 409) throw err; }
  }
}
console.log('Datos demo listos: admin (ADMIN), analyst (ANALYST+USER) y user (USER).');
console.log('Usuarios: admin / ChangeMe-Admin-2026!, analyst / Analyst-Pass-2026!, user / User-Secure-2026!');
