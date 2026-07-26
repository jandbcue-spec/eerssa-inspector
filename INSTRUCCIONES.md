# EERSSA Inspector — Instalación y puesta en marcha

## 1. Qué contiene esta entrega

```
/
├── index.html              (la app completa)
├── manifest.webmanifest     (metadatos de instalación PWA)
├── sw.js                    (service worker: caché offline)
├── icons/
│   ├── icon-192.png
│   ├── icon-512.png
│   └── icon-512-maskable.png
└── supabase/
    └── schema.sql            (script para crear las tablas en Supabase)
```

Estos archivos deben publicarse **juntos, en la misma carpeta**, en un
servidor con **HTTPS** (los service workers no funcionan en `http://`
salvo en `localhost`). Cualquiera de estas opciones sirve:

- Un hosting gratuito: Netlify, Vercel, GitHub Pages, Cloudflare Pages.
- Un servidor propio de EERSSA con certificado SSL.
- Firebase Hosting.

No requiere backend propio: toda la lógica corre en el navegador y
habla directamente con Supabase.

## 2. Configurar el proyecto en Supabase

1. Crear una cuenta/proyecto en [supabase.com](https://supabase.com) (plan gratuito alcanza para empezar).
2. Ir a **SQL Editor → New query**, pegar el contenido de `supabase/schema.sql` y ejecutarlo.
   Esto crea:
   - la tabla `inspecciones` (con las políticas de seguridad RLS),
   - el bucket de Storage `fotos-inspecciones` para las fotos de día/noche.
3. Ir a **Authentication → Users → Add user** y crear un usuario por
   cada inspector, con correo `usuario@eerssa.gob.ec` (o el que se prefiera)
   y una contraseña temporal.
4. Ir a **Settings → API** y copiar:
   - **Project URL**
   - **anon public key**

## 3. Configurar la app con esos datos

1. Abrir la app (en el navegador o ya instalada).
2. Ir a **Ajustes → Conexión Supabase**.
3. Pegar la **URL del proyecto** y la **clave anon/public**.
4. Tocar **Probar conexión** y luego **Guardar**.

Esto se guarda únicamente en ese dispositivo (en IndexedDB), no en el código.

## 4. Iniciar sesión

En el login, el inspector puede escribir solo su usuario/cédula
(la app completa automáticamente `@eerssa.gob.ec`) o su correo completo.
La primera vez **se requiere conexión a internet** para validar las
credenciales contra Supabase. Después de ese primer inicio de sesión
exitoso, la app guarda la sesión y permite entrar sin internet las
veces siguientes.

## 5. Instalar en el celular o tablet

**Android (Chrome):** abrir la URL → menú (⋮) → **"Instalar app"** o
**"Agregar a pantalla de inicio"**.

**iPhone/iPad (Safari):** abrir la URL → botón compartir (□↑) →
**"Añadir a pantalla de inicio"**.

Una vez instalada, abre en pantalla completa, sin barra del navegador,
con su propio ícono — como cualquier otra app.

## 6. Cómo funciona el trabajo sin conexión

- **Toda inspección se guarda primero en el dispositivo** (IndexedDB),
  exista o no internet. Nunca se pierde una inspección por falta de señal.
- Cuando el celular recupera conexión, la app **sincroniza automáticamente**
  en segundo plano: sube las fotografías al bucket de Supabase y registra
  los datos en la tabla `inspecciones`.
- También se puede forzar la sincronización manualmente desde
  **Ajustes → Sincronizar datos**.
- Cada inspección muestra un pequeño ícono de nube:
  - ☁ gris = guardada localmente, pendiente de subir.
  - ☁✓ verde = ya sincronizada con Supabase.
  - ☁! rojo = hubo un error al sincronizar (se puede reintentar desde el detalle).
- El estado **"PENDIENTE"** (con el ícono de alerta) es distinto: significa
  que a esa inspección le falta la foto de día o de noche, sin importar
  si ya se sincronizó o no.

## 7. Limitaciones actuales y próximos pasos sugeridos

Esta es una primera versión funcional pensada para validar el flujo
completo con datos reales. Antes de un despliegue institucional a gran
escala conviene reforzar:

- **Renovación de sesión:** hoy la sesión cacheada no se refresca sola
  si el token expira estando offline por mucho tiempo; conviene forzar
  un refresh cuando vuelve la conexión.
- **Privacidad de fotos:** el bucket se creó como público para simplificar
  el prototipo. Si las fotos no deben ser accesibles por URL directa,
  cambiar el bucket a privado y servir con *signed URLs*.
- **Manejo de conflictos:** si dos inspectores editan la misma inspección
  sin conexión, gana la última sincronización (no hay merge automático).
- **Notificaciones push reales** (hoy son solo visuales dentro de la app).
- **Perfil de usuario**: por ahora se guarda solo localmente; se puede
  sincronizar contra una tabla `profiles` en Supabase si se necesita.
