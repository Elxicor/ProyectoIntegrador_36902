# Proyecto Integrador del Primer Parcial — AUTH + STEGO

**Asignatura:** Desarrollo de Software Seguro — DCCO / ESPE  
**Integrantes:** Danna Andrade, David Pilaguano y Erick Tufiño  
**Entrega:** Backend V1, autenticación JWT/RBAC y detección estadística de esteganografía.

Este repositorio contiene **dos microservicios REST independientes** escritos en NestJS:

- **AUTH:** usuarios, roles, asignación N:M, contraseñas Argon2id, JWT RS256, autorización RBAC dinámica y auditoría; persiste en PostgreSQL.
- **STEGO:** recibe PNG, verifica el JWT, consulta el permiso actual en AUTH, aplica validaciones y un detector estadístico LSB, y registra resultados en SQLite.


## 1. Requisitos de instalación

| Elemento | ¿Para qué? | Requisito |
|---|---|---|
| Git | Clonar el repositorio | `git --version` |
| Docker Desktop o Docker Engine + Compose | Construir y ejecutar los servicios | `docker --version` y `docker compose version` |
| Windows PowerShell 5.1 o PowerShell 7 | Scripts `.ps1` en Windows | `$PSVersionTable.PSVersion` |
| Postman (opcional) | Ejecutar la colección REST | Importar los dos archivos JSON |
| Navegador | Abrir Swagger y consultar rutas | Cualquiera actual |

No es necesario instalar Node.js, PostgreSQL ni OpenSSL en Windows: las aplicaciones, PostgreSQL y los scripts de inicialización se ejecutan en contenedores; si OpenSSL no está disponible en el equipo, el generador utiliza Docker. Para macOS/Linux hay un script Bash equivalente.

**Conexión a Internet durante la primera construcción:** Docker necesita descargar las imágenes base y las dependencias npm. Las siguientes ejecuciones reutilizan las imágenes ya construidas.

## 2. Clonar y ejecutar desde cero

### Windows (PowerShell 5.1 o 7)

1. Inicie Docker Desktop y compruebe que está funcionando.
2. Abra PowerShell en la carpeta donde quiera guardar el proyecto.
3. Ejecute exactamente:

```powershell
git clone https://github.com/Elxicor/ProyectoIntegrador_36902.git
cd ProyectoIntegrador_36902
.\scripts\start-demo.ps1
```

`start-demo.ps1` realiza este procedimiento automáticamente:

1. Genera claves RSA para JWT, una CA local y un certificado HTTPS, si no existen.
2. Crea la credencial de comunicación interna AUTH–STEGO.
3. Valida `docker-compose.yml`.
4. Construye y levanta `auth-db`, `auth` y `stego`, esperando a que respondan los healthchecks.
5. Ejecuta la migración inicial de AUTH y prepara ADMIN, ANALYST y USER desde el contenedor AUTH.
6. Muestra el estado final de los contenedores y las URLs de las APIs.

No es necesario crear previamente una base de datos ni copiar claves desde otro equipo.

### Linux o macOS (terminal Bash)

```bash
git clone https://github.com/Elxicor/ProyectoIntegrador_36902.git
cd ProyectoIntegrador_36902
bash scripts/start-demo.sh
```

Este script utiliza OpenSSL local, si existe, o Docker para generar las claves; inicia los mismos contenedores y crea las mismas cuentas. El arranque está previsto para Docker Compose moderno con soporte de `--wait`.

### Inicio manual o posterior

Si ya ejecutó el inicio por primera vez, puede reutilizar:

```powershell
docker compose up -d
docker compose ps
```

Si necesita reconstruir después de cambiar el código:

```powershell
docker compose up -d --build --wait
.\scripts\setup-demo.ps1
```

Si quiere hacer cada operación inicial por separado:

```powershell
.\scripts\generate-secrets.ps1
docker compose config --quiet
docker compose up -d --build --wait
.\scripts\setup-demo.ps1
docker compose ps
```

**Nota:** `setup-demo.ps1` requiere que AUTH ya esté ejecutándose. No lo lance antes de `docker compose up`.

### Qué se debería ver

`docker compose ps` debe mostrar los contenedores `auth-db`, `auth` y `stego` iniciados. `auth-db`, `auth` y `stego` disponen de healthchecks. Los nombres completos pueden tener prefijos definidos por Compose.

| Servicio | Dirección | Función |
|---|---|---|
| AUTH Swagger | `https://localhost:3001/docs` | Explorar la API de identidad |
| STEGO Swagger | `http://localhost:3002/docs` | Explorar la API de imágenes |
| AUTH salud | `https://localhost:3001/health` | Respuesta de estado de AUTH |
| STEGO salud | `http://localhost:3002/api/health` | Respuesta de estado de STEGO |
| PostgreSQL | `127.0.0.1:5435` | Persistencia interna de AUTH |

AUTH emplea HTTPS con una CA generada por el proyecto. Es normal que el navegador pida confirmar la confianza en ese certificado local. Los scripts usan la CA almacenada en `secrets/tls/ca.crt` para las pruebas de AUTH.

## 3. Usuarios de demostración

El inicializador crea o verifica estas identidades:

| Usuario (`identity`) | Contraseña | Roles efectivos |
|---|---|---|
| `admin` | `ChangeMe-Admin-2026!` | `ADMIN` |
| `analyst` | `Analyst-Pass-2026!` | `ANALYST`, `USER` |
| `user` | `User-Secure-2026!` | `USER` |

`setup-demo.ps1` se puede repetir: no duplica las relaciones ya existentes. Las cuentas se almacenan en PostgreSQL. Los JWT **no contienen roles**; las operaciones sensibles consultan las asignaciones vigentes.

Para reponer la asignación ANALYST después de una demostración de revocación:

```powershell
.\scripts\setup-demo.ps1
```

El inicializador no restablece contraseñas que hayan sido cambiadas manualmente. En una instalación nueva, utilice las contraseñas mostradas arriba.

## 4. Estructura del repositorio

```text
ProyectoIntegrador_36902/
├── auth/                        Microservicio NestJS, entidades y migración
│   ├── src/
│   │   ├── auth/                JWT, login, logout, guards, autorización
│   │   ├── users/               Usuarios y DTO
│   │   ├── roles/               Roles y DTO
│   │   ├── user-roles/          Relación N:M
│   │   └── migrations/          Esquema inicial de PostgreSQL
│   ├── scripts/                 Soporte del generador de tokens de prueba
│   ├── Dockerfile
│   ├── package.json
│   ├── package-lock.json
│   └── .env.example
├── stego/                       Microservicio NestJS y persistencia SQLite
│   ├── src/steganography/       Controlador, guard y detector LSB
│   ├── Dockerfile
│   ├── package.json
│   ├── package-lock.json
│   └── .env.example
├── samples/
│   ├── original/                PNG sin modificaciones conocidas
│   ├── stego/                   PNG alterados con LSB
│   └── invalid/                 Cinco archivos para rechazos T10
├── scripts/                     Inicio, configuración y pruebas reproducibles
├── documentacion/               Informe LaTeX/PDF y contratos OpenAPI YAML
├── docker-compose.yml           AUTH, STEGO, PostgreSQL y volúmenes
├── .env.example                 Variables opcionales de Docker Compose
├── postman_collection.json
├── postman_environment.json
└── README.md                    Esta guía
```

No hay dependencias `node_modules` ni carpetas compiladas dentro del repositorio; Docker ejecuta `npm ci` durante la construcción. Las claves y bases de datos se generan en cada instalación.

## 5. Arquitectura y límites de confianza

```text
              CLIENTE (Postman / Swagger / curl)
                  |                     |
           HTTPS login               HTTP local + Bearer JWT
                  v                     v
          +----------------+     +----------------+
          | AUTH :3001     |<----| STEGO :3002    |
          | NestJS         |     | NestJS         |
          | Usuarios, RBAC |     | PNG + LSB      |
          | JWT RS256      |     | SQLite         |
          +-------+--------+     +----------------+
                  |                    |
                  v                    v
           PostgreSQL (N:M)    Volumen stego_data

Comunicación STEGO -> AUTH: HTTPS + CA local + x-service-token
Autorización: token del usuario + acción + consulta actual a PostgreSQL
```

Cada backend tiene su **Dockerfile, dependencias, proceso y API**. `auth-db` no cuenta como otro microservicio; es infraestructura. STEGO **no accede directamente a PostgreSQL**, no almacena contraseñas y solo recibe la **clave pública** JWT. La clave privada permanece montada únicamente en AUTH.

**Separación de confianza:** el cliente no decide su propio rol; STEGO valida la firma del JWT y consulta a AUTH por una decisión vigente. AUTH vuelve a verificar la sesión y obtiene roles de la base de datos. Si AUTH no responde, STEGO rechaza la operación con 503 antes de procesar la imagen.

## 6. Modelo N:M y funcionamiento JWT/RBAC

```text
users (id PK)          roles (id PK)
       |                     |
       +--- user_roles ------+
            id PK
            user_id FK
            role_id FK
            assigned_at
            UNIQUE(user_id, role_id)
```

`users` almacena `username`, `email`, `password_hash` Argon2id, `status`, `token_version`, `created_at` y `updated_at`; `roles` mantiene `name`, descripción, estado y fechas. `user_roles` materializa las relaciones y evita pares duplicados. La migración `auth/src/migrations/1793740000000-InitialIdentity.ts` crea el esquema automáticamente al iniciar AUTH con una base nueva; `DB_SYNCHRONIZE=false`.

El JWT se firma con **RS256**: AUTH utiliza su clave privada y STEGO verifica la firma con la pública. El payload contiene `sub`, `username`, `typ`, `tokenVersion`, `iat`, `exp`, `iss` y `aud`, pero no roles. AUTH consulta roles activos en PostgreSQL cuando STEGO solicita autorizar una acción. El token dura 15 minutos por defecto. Logout incrementa `tokenVersion` e invalida tokens anteriores del usuario.

### Matriz de permisos

| Operación | ADMIN | ANALYST | USER |
|---|:---:|:---:|:---:|
| Login y perfil propio | Sí | Sí | Sí |
| Crear/listar/editar usuarios | Sí | No | No |
| Crear/listar/editar roles | Sí | No | No |
| Asignar/quitar roles | Sí | No | No |
| Analizar PNG | Sí | Sí | No |
| Consultar análisis propio | Sí | Sí | No |
| Consultar análisis ajeno | Sí | No | No |
| Consultar autorización interna | Servicio STEGO | Servicio STEGO | Servicio STEGO |

El endpoint interno no está disponible por simple rol: exige autenticación de **servicio** (`x-service-token`) y el JWT del usuario a evaluar.

## 7. API AUTH — uso paso a paso

**URL base:** `https://localhost:3001`  
**Swagger:** `https://localhost:3001/docs`  
**OpenAPI:** `https://localhost:3001/docs-json`, o `documentacion/openapi/auth.openapi.yaml`.

Para probar en Postman, cree una petición HTTP, seleccione método y URL, y coloque los datos en **Body → raw → JSON**. Para rutas protegidas, en **Authorization → Bearer Token**, pegue el `access_token` obtenido en el login; Postman colocará automáticamente `Authorization: Bearer ...`.

### 7.1 Iniciar sesión

**POST** `/api/auth/login` — público, sujeto a límite de intentos.

```json
{
  "identity": "admin",
  "password": "ChangeMe-Admin-2026!"
}
```

Respuesta correcta: **201 Created**, con `access_token`, `token_type` y `expires_in`. Una contraseña incorrecta produce **401 Unauthorized**.

### 7.2 Consultar el perfil

**GET** `/api/auth/profile` con JWT en Authorization. Respuesta **200 OK** si el token es válido; **401** si falta, expiró, fue alterado o se invalidó la sesión.

### 7.3 Cerrar sesión

**POST** `/api/auth/logout` con JWT. Respuesta **201 Created** con `logged_out: true`. Después, reutilizar ese mismo JWT en una ruta protegida produce **401**. Para continuar, inicie sesión nuevamente.

### 7.4 Crear un usuario (ADMIN)

**POST** `/api/users`, JWT de ADMIN, Body JSON:

```json
{
  "cedula": "3333333333",
  "nombres": "Usuario",
  "apellidos": "Evaluacion",
  "fechaNacimiento": "1995-01-01",
  "username": "evaluador_demo",
  "email": "evaluador_demo@example.local",
  "password": "Evaluador-Pass-2026!"
}
```

Obtendrá **201** y un UUID `id`. Guarde ese UUID. Repetir el mismo `username`/correo/cédula produce **409 Conflict**. Los campos se validan con DTO y se almacena un hash Argon2id, no la contraseña de texto plano.

**GET** `/api/users`: lista usuarios (ADMIN).  
**GET** `/api/users/{id}`: devuelve el usuario con ese identificador (ADMIN).  
**PATCH** `/api/users/{id}`: modifica campos permitidos; ejemplo `{"nombres":"Usuario actualizado"}` (ADMIN). No requiere enviar todos los campos otra vez.

### 7.5 Consultar y gestionar roles (ADMIN)

**GET** `/api/roles` devuelve los roles y sus UUID. Los roles base `ADMIN`, `ANALYST` y `USER` se crean automáticamente.  
**POST** `/api/roles` permite crear un rol dentro del catálogo permitido por el DTO, si no existe; al arrancar una base nueva, los tres ya existen y repetirlos suele devolver **409**.  
**PATCH** `/api/roles/{id}` permite actualizar un rol; ejemplo `{"description":"Análisis estadístico de PNG"}`.

El DTO actual admite únicamente los nombres `ADMIN`, `ANALYST` y `USER`; agregar otros requeriría actualizar su validación y la política de autorización.

### 7.6 Asignar, listar y retirar roles (ADMIN)

Primero obtenga el `id` de un usuario con `GET /api/users` y el `id` de un rol con `GET /api/roles`.

**POST** `/api/user-roles`:

```json
{
  "userId": "UUID_REAL_DEL_USUARIO",
  "roleId": "UUID_REAL_DEL_ROL"
}
```

Respuesta **201**. Repetir la misma relación debe producir **409**; esto demuestra `UNIQUE(user_id, role_id)`.

**GET** `/api/user-roles`: lista relaciones, cada una con su `id`, usuario y rol. Muestra que `analyst` tiene ANALYST+USER, y que el rol USER está asignado tanto a `analyst` como a `user`.

**DELETE** `/api/user-roles/{id}`: utiliza **el ID de la asignación**, no el ID del usuario ni el del rol; devuelve **200** con `deleted: true`. Es el procedimiento utilizado para demostrar revocación inmediata.

### 7.7 API interna de autorización

**POST** `/internal/authorization/check` no es una ruta de uso público; STEGO envía automáticamente un `subject_token`, una `action` (`steganography.analyze` o `steganography.result.read`) y opcionalmente `resource_id`, además de `x-service-token` y HTTPS. El servicio responde con `allowed` y los roles vigentes de la sesión. La clave de autenticación entre servicios se genera localmente.

## 8. API STEGO — analizar y recuperar imágenes

**URL base:** `http://localhost:3002`  
**Swagger:** `http://localhost:3002/docs`  
**OpenAPI:** `http://localhost:3002/docs-json`, o `documentacion/openapi/stego.openapi.yaml`.

### 8.1 Analizar una imagen PNG

1. Abra Postman y haga `POST https://localhost:3001/api/auth/login` con usuario ADMIN o ANALYST.
2. Copie el valor `access_token` de la respuesta.
3. Cree otra petición **POST** `http://localhost:3002/api/steganography/analyze`.
4. En **Authorization → Bearer Token**, pegue el token (sin escribir `Bearer` en el campo).
5. En **Body → form-data**, cree una fila **Key:** `file`; cambie el tipo **Text → File**.
6. En **Value → Select Files**, seleccione `samples/original/reference.png` desde la copia local del repositorio.
7. Pulse **Send**. La respuesta esperada es **201 Created** y un JSON con UUID `id`, `filename`, `sha256`, `technique`, `status`, `indicators`, `action`, `limitations` y `created_at`.
8. Repita con `samples/stego/lsb-random-payload.png` y compare `status` e `indicators.anomaly_score`.

Se aceptan archivos PNG reales, no imágenes renombradas de otro formato. Límite: **5 MiB** y **16 millones de píxeles**. El procesamiento usa la librería Sharp.

### 8.2 Interpretar el detector

El detector transforma la imagen a bytes RGB, extrae el bit menos significativo con `byte & 1` y calcula:

- `lsb_one_ratio`: proporción de unos en los bits menos significativos.
- `transition_rate`: proporción de transiciones entre bits adyacentes.
- `chi_square`: desviación estadística del reparto de ceros y unos respecto del balance 50/50.
- `anomaly_score`: promedio de cercanía al 50 % de unos y de transiciones (rango 0 a 1).

Si el score es al menos **0,97**, clasifica `sospechoso`; entre **0,85** y **0,97**, `no_concluyente`; menor que **0,85**, `sin_indicios`. `chi_square` se informa como indicador, pero no determina por sí solo la clase. La acción `cuarentena` es una **política registrada/recomendada**, no traslado físico del archivo a otra carpeta.

| Muestra incluida | Clasificación de referencia | Qué observar |
|---|---|---|
| `samples/original/reference.png` | `sin_indicios` | Patrón sin señal estadística de sustitución aleatoria |
| `samples/original/checkerboard.png` | `sin_indicios` | Patrón repetitivo |
| `samples/original/noisy-unmodified.png` | `sospechoso` | Ejemplo de falso positivo posible |
| `samples/stego/lsb-random-payload.png` | `sospechoso` | Alteraciones LSB con bits pseudoaleatorios |
| `samples/stego/lsb-sparse-payload.png` | `sin_indicios` | Ejemplo de falso negativo posible |
| `samples/stego/lsb-inconclusive-pattern.png` | `no_concluyente` | Señal intermedia |

Los resultados son **indicios estadísticos**, no prueba definitiva de un mensaje oculto. El detector no extrae mensajes y no cubre todas las técnicas de esteganografía.

### 8.3 Recuperar un análisis guardado

Copie `id` desde la respuesta de POST y ejecute:

**GET** `http://localhost:3002/api/steganography/results/UUID_DEL_ANALISIS` con JWT en Bearer Token. La respuesta **200** contiene el registro previamente guardado. Si ANALYST intenta consultar el análisis perteneciente a otro usuario, responde **403**; ADMIN puede consultar resultados ajenos.

### 8.4 Prueba rápida desde PowerShell, sin Postman

```powershell
# Se ejecuta desde la raíz del repositorio, una vez que los servicios estén activos.
$login = curl.exe --silent --ssl-no-revoke --cacert .\secrets\tls\ca.crt `
  -H 'Content-Type: application/json' `
  -d '{"identity":"admin","password":"ChangeMe-Admin-2026!"}' `
  https://localhost:3001/api/auth/login | ConvertFrom-Json

curl.exe -H "Authorization: Bearer $($login.access_token)" `
  -F 'file=@samples/original/reference.png;type=image/png' `
  http://localhost:3002/api/steganography/analyze
```

**Importante:** use **POST** para `/api/steganography/analyze` y **GET** para `/api/steganography/results/{id}`. Una petición GET al endpoint de análisis devuelve 404.

## 9. Colección Postman — importar y ejecutar

1. Abra Postman → **Import**.
2. Seleccione `postman_collection.json` y `postman_environment.json`.
3. Seleccione el entorno **AUTH–STEGO desarrollo local**.
4. En una instalación nueva, ejecute los tres logins de la carpeta `01. Sesiones`; guardan automáticamente `adminJwt`, `analystJwt` y `userJwt`.
5. Abra las peticiones de la carpeta de estudio que desea usar. En los `multipart/form-data`, **seleccione de nuevo el archivo local** si Postman no resuelve la ruta relativa guardada en la colección.
6. Las carpetas adicionales cubren salud/perfil, CRUD de usuarios/roles/N:M y el análisis de imágenes originales, LSB e inconclusas.

**Orden recomendado de carpetas:** `06. Salud y perfil` → `01. Sesiones` → `07. CRUD usuarios, roles y N:M` → `08. Práctica de esteganografía` → `02. Firma y claims` → `03. RBAC dinámico` → `04. Logout, propiedad y disponibilidad` → `05. Archivos T10`.

Para la prueba de revocación, primero ejecute **Listar asignaciones (ADMIN)** (captura `analystAssignmentId`), luego **ANALYST analiza**, luego **Retirar asignación ANALYST**, y finalmente **Revocado: reutilizar mismo JWT**. **No vuelva a iniciar sesión entre retirar y reutilizar**. Después, para devolver el rol, ejecute `scripts/setup-demo.ps1`.

Para comprobar acceso horizontal, primero ejecute **ADMIN analiza** (guarda `adminAnalysisId`), después **Consultar resultado ajeno** con JWT ANALYST.

La colección también puede ejecutarse completa desde la raíz con Newman (requiere Node.js solo para este modo opcional):

```powershell
npx --yes newman run postman_collection.json -e postman_environment.json --insecure --working-dir .
```

La ejecución completa resuelve automáticamente los UUID existentes y es repetible. El caso **Fail closed (AUTH detenido) → 503** se omite en Newman porque exige detener AUTH desde otra terminal; para ejecutarlo manualmente, detenga AUTH, establezca `runFailClosed=true` en el entorno, envíe la petición y restaure AUTH. La comprobación automatizada equivalente y recomendada es `scripts/test-fail-closed.ps1`.

Para el token expirado, ejecute en PowerShell `scripts/print-expired-jwt.ps1`, copie el JWT resultante en la variable `expiredJwt` del entorno Postman y ejecute **JWT expirado → 401**. Alternativamente, use `scripts/test-core-security.ps1`, que genera y prueba automáticamente un JWT expirado en el contenedor.

Las variables `authUrl` y `stegoUrl` corresponden a la publicación local por defecto. Para modificar los puertos publicados, actualice el entorno Postman de manera coherente.

## 10. Pruebas oficiales T01–T12 — instrucciones de ejecución

Los scripts PowerShell se ejecutan **desde la raíz del repositorio**, con Docker iniciado. Los `.ps1` utilizan `curl.exe` y funcionan con Windows PowerShell 5.1 o PowerShell 7. El login tiene un límite de cinco intentos por minuto; si encadena muchas pruebas y aparece **429**, deje transcurrir un minuto y reintente.

`test-all.ps1` respeta esa ventana antes de T08. `test-fail-closed.ps1` muestra el HTTP real del login previo y hace como máximo un reintento después de 65 segundos, exclusivamente si AUTH responde 429.

| ID | Cómo ejecutar | Respuesta o evidencia que debe observar |
|---|---|---|
| **T01** | `.\scripts\test-independence.ps1` | Detiene STEGO; AUTH sigue respondiendo 200; restaura STEGO |
| **T02** | `.\scripts\test-core-security.ps1` o dos logins en Postman | Contraseña correcta → JWT; incorrecta → 401 |
| **T03** | `.\scripts\test-core-security.ps1`, `.\scripts\test-jwt-special.ps1` | Sin token, alterado, expirado, claims falsos → 401 |
| **T04** | `test-core-security.ps1` o `USER analiza` en Postman | USER intenta analizar → 403 |
| **T05** | `GET /api/user-roles` o `test-core-security.ps1` | Un usuario con dos roles; rol USER asignado a dos usuarios |
| **T06** | `POST /api/user-roles` duplicado o `test-core-security.ps1` | 409 y una sola asignación persistida |
| **T07** | Revocar ANALYST y repetir con **el mismo** JWT | Antes 201; después 403 (el token sigue bien firmado) |
| **T08** | `.\scripts\test-fail-closed.ps1` | AUTH detenido → STEGO 503; se restaura AUTH |
| **T09** | `.\scripts\test-detector.ps1` | Imagen de referencia y LSB: métricas y clasificaciones reales |
| **T10** | `.\scripts\test-t10.ps1` | 413, 422, 422, 415, 415; no se guardan análisis rechazados |
| **T11** | Crear análisis ADMIN; consultarlo con JWT ANALYST | 403 por recurso ajeno; 200 para ADMIN |
| **T12** | `docker compose logs --tail 150 auth stego` | Eventos JSON de acceso, autorización y análisis, con `requestId` |

### 10.1 Ejecutar las pruebas automatizadas por grupos

```powershell
.\scripts\test-core-security.ps1     # T02 a T07, T11 y observabilidad
.\scripts\test-detector.ps1          # T09 y límites de precisión
.\scripts\test-t10.ps1               # T10, archivos adversos
.\scripts\test-jwt-special.ps1       # Claims modificados, alg=none, logout
.\scripts\test-independence.ps1      # T01, detiene y restaura STEGO
.\scripts\test-fail-closed.ps1       # T08, detiene y restaura AUTH
```

Para ejecutar los grupos en un orden controlado, con pausas de 65 segundos para respetar el rate limit del login:

```powershell
.\scripts\test-all.ps1
```

Las pruebas de revocación intentan restaurar las asignaciones. Si el proceso se interrumpe, ejecute `.\scripts\setup-demo.ps1` para recuperarlas.

### 10.2 Verificar los cinco rechazos T10 manualmente

En Postman, con JWT ADMIN o ANALYST, haga `POST /api/steganography/analyze` con **Body → form-data → file** y seleccione uno de estos archivos:

| Archivo | HTTP | Motivo |
|---|---|---|
| `samples/invalid/oversized.png` | 413 | Más de 5 MiB |
| `samples/invalid/corrupt.png` | 422 | Imagen truncada |
| `samples/invalid/excessive-pixels.png` | 422 | 25 millones de píxeles, sobre el límite |
| `samples/invalid/unsupported.gif` | 415 | GIF no admitido |
| `samples/invalid/jpeg-named-png.png` | 415 | Extensión PNG, contenido JPEG |

Al enviar las imágenes que se hacen pasar por PNG, use MIME `image/png` para reproducir exactamente la prueba de detección de firma, en lugar de depender únicamente de MIME declarado.

### 10.3 Verificar permanencia tras reinicio

```powershell
# Consulta recuento de resultados STEGO
$antes = docker compose exec -T stego node -e "const D=require('better-sqlite3');console.log(new D('/app/data/stego.db').prepare('select count(*) n from analyses').get().n)"
docker compose restart stego
$despues = docker compose exec -T stego node -e "const D=require('better-sqlite3');console.log(new D('/app/data/stego.db').prepare('select count(*) n from analyses').get().n)"
Write-Host "Antes: $antes - Después: $despues"
```

Los valores deben coincidir. Los datos de AUTH están en el volumen `auth_data`; los de STEGO, en `stego_data`. `docker compose down` conserva los volúmenes. **No utilice `down -v` para demostrar persistencia**, porque borra los volúmenes del proyecto.

### 10.4 Auditoría (T12)

```powershell
docker compose logs --tail 150 auth stego
docker compose logs --tail 250 auth stego | Select-String 'authentication_|authorization_|analysis_|requestId|logout'
```

Los eventos contienen fecha, identificador de solicitud y datos contextuales de la decisión. No registran contraseñas ni JWT completos. Una petición puede seguirse entre AUTH y STEGO mediante `x-request-id`. Para obtener evidencia nueva, ejecute primero un login correcto/incorrecto y un análisis, y después consulte los logs.

## 11. Pruebas unitarias, compilación y verificación del repositorio

Los dos proyectos incluyen pruebas unitarias en sus respectivas carpetas y scripts npm. Para ejecutarlas **sin instalar Node.js en el equipo**, construya la etapa `build` de cada Dockerfile (que conserva las dependencias de desarrollo):

```powershell
# Tests AUTH con Jest
docker build --target build -t proyecto-auth-tests ./auth
docker run --rm --entrypoint npm proyecto-auth-tests test

# Tests STEGO con Vitest
docker build --target build -t proyecto-stego-tests ./stego
docker run --rm --entrypoint npm proyecto-stego-tests test
```

Estas imágenes de prueba son distintas de las imágenes finales usadas por Compose. La etapa de construcción ejecuta `npm ci` y `npm run build`, por lo que también verifica la compilación.

Para revisar la integridad de archivos requeridos:

```powershell
.\scripts\verify-repository.ps1
```

Este verificador necesita que ya se haya generado `secrets/service.env` mediante el inicio automático.

## 12. Estados HTTP y diagnóstico

| Código | Significado en el proyecto | Ejemplo |
|---|---|---|
| **200** | Consulta correcta | Perfil, usuarios, resultado guardado |
| **201** | Creación / acción POST correcta | Login, análisis, asignación |
| **400** | Cuerpo inválido o falta archivo | DTO incompleto |
| **401** | Sin autenticación o JWT no válido | Token alterado, vencido o logout |
| **403** | Identidad válida sin autorización | USER analiza; ANALYST intenta ver resultado ajeno |
| **409** | Conflicto de unicidad | Repetir usuario o asignación de rol |
| **413** | Archivo demasiado grande | Más de 5 MiB |
| **415** | Formato/firma real no admitido | GIF, JPEG renombrado PNG |
| **422** | Archivo corrupto o demasiados píxeles | PNG truncado, 25 Mpx |
| **429** | Demasiados intentos de login | Supera 5 por minuto |
| **503** | AUTH no disponible o decisión no verificable | Fail closed de STEGO |

**Swagger AUTH no abre:** compruebe `docker compose ps`, luego `docker compose logs --tail 80 auth` y que la URL empiece por `https://`.  
**Swagger STEGO devuelve 404:** utilice `http://localhost:3002/docs`, **no** `/api/docs`.  
**PowerShell muestra `SkipCertificateCheck` inválido:** use los scripts de este repositorio; ya no dependen de esa opción.  
**OpenSSL intenta leer `PostgreSQL\psqlODBC\etc\openssl.cnf`:** los scripts corregidos usan una configuración temporal propia; vuelva a ejecutar `scripts/start-demo.ps1`. Si una ejecución previa se interrumpió, los certificados faltantes se completan sin eliminar los ya generados.  
**`test-all.ps1` muestra `service "auth" is not running`:** todavía no se completó la instalación; primero ejecute `scripts/start-demo.ps1` y confirme los tres contenedores con `docker compose ps`.  
**Puerto ocupado:** cambie `AUTH_PORT`, `STEGO_PORT` o `AUTH_DB_PORT` en un `.env` creado a partir de `.env.example`, y actualice las URLs de Postman.  
**Token que funcionaba devuelve 401:** quizá pasaron los 15 minutos o se ejecutó logout; haga login nuevamente.  
**ANALYST devuelve 403 después de la prueba T07:** ejecute `scripts/setup-demo.ps1` para restaurar la relación.  
**Error de Docker al compilar:** confirme Docker Desktop, conexión inicial a Internet y disponibilidad de disco; revise `docker compose logs`.  
**Postman no encuentra el PNG:** vuelva a seleccionarlo en el campo File; las rutas guardadas no se transfieren automáticamente a todos los equipos.  
**Iniciar servicios en otro equipo:** clone de nuevo y ejecute `scripts/start-demo.ps1`; los volúmenes no se transfieren desde la computadora original, y `setup-demo` prepara sus usuarios.

## 13. Operación y configuración

```powershell
docker compose ps                  # Ver servicios
docker compose logs -f auth stego   # Seguir logs
docker compose stop stego          # Detener únicamente STEGO
docker compose start stego         # Restaurar STEGO
docker compose stop auth           # Detener únicamente AUTH
docker compose start auth          # Restaurar AUTH
docker compose down                # Detener todos conservando bases
docker compose up -d               # Volver a iniciar
```

Los ejemplos de variables de cada aplicación están en `auth/.env.example` y `stego/.env.example`. Para Compose, el archivo raíz `.env.example` documenta puertos y contraseñas de demostración. Los valores de desarrollo son suficientes para ejecutar el repositorio sin crear un `.env` adicional.

Dentro de Docker, STEGO llama a **`https://auth:3001`** por la red de Compose. No utiliza `localhost:3001` para la conexión entre contenedores. La credencial de servicio se crea en `secrets/service.env` y las claves/certificados se crean en `secrets/jwt` y `secrets/tls` al iniciar por primera vez.

La API STEGO se publica por HTTP **solo en loopback** (`127.0.0.1`) en la configuración de demostración. Para acceder desde otra máquina se necesita un túnel/proxy HTTPS o una configuración de red adecuada; **esto no es exigido para ejecutar y evaluar el Backend V1 localmente**.

## 14. Fundamentos de seguridad, limitaciones y riesgos

| Activo o componente | Riesgo o amenaza | Control incorporado | Limitación |
|---|---|---|---|
| Contraseñas | Exposición o ataques de prueba masiva | Argon2id y límite de login | Ataques distribuidos siguen siendo posibles |
| JWT | Falsificación o alteración | RS256, `exp`, `iss`, `aud`, `typ` | El token robado puede utilizarse hasta revocación o expiración |
| Roles | Permisos antiguos | Consulta vigente de `user_roles` en AUTH | STEGO depende de la disponibilidad de AUTH |
| Comunicación interna | Suplantación de STEGO | HTTPS verificado y token de servicio | No se usa mTLS |
| Consultas de resultados | IDOR (acceso horizontal) | Rol actual y verificación de propietario | ADMIN tiene permiso administrativo sobre resultados |
| Archivos | MIME falso, archivo malformado y agotamiento | Firma real, límite de bytes/píxeles, Sharp | Solo PNG; detector LSB heurístico |
| Auditoría | Falta de trazabilidad | Eventos JSON y request ID | No hay sistema externo de retención inmutable |
| Base de datos | Pérdida de resultados al recrear contenedores | Volúmenes persistentes y migración | No hay respaldo automático ni replicación |

**Zero Trust:** toda petición protegida verifica JWT y permisos vigentes. **Secure by Design:** separación real, mínimos privilegios, rechazo de archivos inválidos, confidencialidad de claves. **Shift Left Security:** pruebas unitarias y escenarios adversos ejecutables antes de entregar. Los principios de ISO/IEC 27001 e ISO/IEC 27034 se utilizan como referencias de gestión de controles y seguridad de aplicaciones, **sin afirmar certificación**.

El detector es deliberadamente limitado: una imagen de ruido natural puede resultar sospechosa (falso positivo), y un ocultamiento disperso puede no detectarse (falso negativo). Los umbrales son una configuración del método actual y no constituyen garantías estadísticas universales.

## 15. Documentación, OpenAPI y evidencias

- **Informe académico:** `documentacion/main.pdf` y `documentacion/main.tex` (con sus figuras y portada ESPE).
- **Especificaciones OpenAPI legibles:** `documentacion/openapi/auth.openapi.yaml` y `documentacion/openapi/stego.openapi.yaml`. La versión generada por NestJS también puede consultarse en los endpoints Swagger `/docs-json` mientras los servicios estén activos.
- **Colección REST:** `postman_collection.json` y `postman_environment.json` (38 peticiones agrupadas).
- **Muestras:** `samples/original`, `samples/stego` y `samples/invalid`.
- **Pruebas:** `scripts/test-core-security.ps1`, `test-jwt-special.ps1`, `test-detector.ps1`, `test-t10.ps1`, `test-independence.ps1`, `test-fail-closed.ps1` y `test-all.ps1`.
- **Registros y evidencia:** ejecute los scripts y conserve su salida y `docker compose logs` correspondientes a la sesión de evaluación. Se adjunta `documentacion/evidencias-pruebas-previas.txt` con resultados de una ejecución anterior, que no sustituye ejecutar la nueva instalación.

## 16. Secuencia corta

1. Clonar el repositorio e iniciar `scripts/start-demo.ps1` (o `.sh`). Mostrar tres contenedores activos.
2. Abrir Swagger de AUTH y STEGO; mostrar que cada servicio responde desde su API propia.
3. Importar la colección Postman. Iniciar sesión como ADMIN, ANALYST y USER; mostrar el header/payload RS256 sin roles.
4. Listar usuarios, roles y asignaciones N:M; crear un usuario nuevo, asignar dos roles y demostrar duplicado 409.
5. Con JWT USER intentar analizar PNG → 403. Con JWT ANALYST analizar PNG → 201.
6. Retirar ANALYST desde AUTH y reutilizar **el mismo JWT** → 403. Restaurar con `setup-demo.ps1`.
7. Enviar un JWT alterado → 401. Si se desea, mostrar `test-jwt-special.ps1` para `iss`, `aud`, `alg=none` y logout.
8. Apagar AUTH conservando STEGO y repetir análisis → 503; restaurar AUTH.
9. Analizar `reference.png`, `lsb-random-payload.png` y `lsb-inconclusive-pattern.png`; comparar `anomaly_score` y explicar las limitaciones.
10. Ejecutar T10 (413/422/415), comprobar que no crea análisis; consultar un resultado ajeno (403) y mostrar auditoría JSON.

Con esta secuencia se recorren la arquitectura, autenticación, persistencia, autorización, detección y evidencia reproducible exigidas para el primer parcial.
