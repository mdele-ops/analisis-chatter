// Servidor local del análisis de chatter.
// La clave se lee solo desde .env y no se envía al navegador.
// Se arranca con: node servidor_chatter.js

const fs = require("fs");
const http = require("http");
const https = require("https");
const path = require("path");
const zlib = require("zlib");

const RAIZ = __dirname;
const PAGINA = path.join(RAIZ, "pagina");

function leerEnv(ruta) {
  const valores = {};
  if (!fs.existsSync(ruta)) return valores;
  for (const linea of fs.readFileSync(ruta, "utf8").split(/\r?\n/)) {
    const limpia = linea.trim();
    if (!limpia || limpia.startsWith("#") || !limpia.includes("=")) continue;
    const corte = limpia.indexOf("=");
    valores[limpia.slice(0, corte).trim()] = limpia.slice(corte + 1).trim().replace(/^["']|["']$/g, "");
  }
  return valores;
}

const ENV = leerEnv(path.join(RAIZ, ".env"));
const API_KEY = ENV.LLM_API_KEY || "";
const BASE_URL = (ENV.LLM_BASE_URL || "https://llm-stage.gm.com/v1").replace(/\/$/, "");
const MODELO = ENV.LLM_MODEL || "gpt-5.4-mini";
const PUERTO = Number(ENV.PORT || "3000");

const INSTRUCCION = [
  "Eres especialista en vibraciones y chatter en torneado. Redactas un informe técnico en español formal",
  "a partir de un resumen calculado por software. No recibes señales crudas ni gráficas: no afirmes haberlas",
  "inspeccionado. No inventes cifras, picos, causas ni resultados. Si un campo es null, falta o hay error,",
  "trátalo como no disponible. Distingue dato medido, inferencia y recomendación.",
  "",
  "CRITERIOS",
  "La máquina reporta 720 rpm, equivalentes a 12 Hz de giro, y un avance de 32 mm/in. Conserva esa unidad;",
  "no la conviertas ni supongas otra convención. La banda es la frecuencia natural ± 125 Hz; si no hay modal,",
  "1300-1550 Hz. Hay indicio en un eje solo cuando su contraste, pico en banda dividido entre la mediana del",
  "espectro de 100 a 3000 Hz fuera de la banda, es mayor que 4. Contraste menor o igual a 4 no activa el",
  "detector en ese eje. Es un indicador heurístico, no confirmación de chatter autoexcitado. Si la mediana",
  "está cerca de cero, no describas el cociente como magnitud física: el fondo es muy pequeño y la razón es",
  "inestable. Coincidir con la frecuencia natural es compatible con resonancia y no prueba chatter",
  "autoexcitado. No atribuyas el origen a los 12 Hz de giro sin evidencia en el resumen. El índice es relativo:",
  "menor es más favorable, con vibración 45%, amplitud modal 35% y fuerza 20%, y suma 0.15 si el detector",
  "marca indicio. No es probabilidad ni frontera de estabilidad. Distingue el RMS resultante global del RMS",
  "por eje.",
  "",
  "INFORME",
  "Entre 350 y 475 palabras. Encabezados en texto plano, sin numerales ni asteriscos. Evita paréntesis salvo",
  "que sean imprescindibles. Secciones exactas: Dictamen; Método; Hallazgos por espesor; Comparación e",
  "interpretación; Recomendaciones y limitaciones.",
  "Dictamen: cuántos ensayos activan el detector y una confianza cualitativa, en una o dos frases.",
  "Método: frecuencia natural, banda, umbral 4, frecuencias de muestreo y unidades, en dos frases como máximo.",
  "Hallazgos por espesor: dos frases por espesor. Di si el detector se activa, qué ejes superan 4 y solo las",
  "cifras que sostienen eso: contraste y pico en banda de los ejes decisivos, RMS global de aceleración, RMS",
  "global de fuerza, crecimiento fin/inicio e índice. Como máximo uno o dos picos representativos. Menciona",
  "datos ausentes solo si cambian la conclusión.",
  "Comparación: ordena por índice y describe la tendencia sin causalidad. Si hay una sola prueba, no inventes",
  "comparaciones.",
  "Recomendaciones: dos acciones de validación. No infieras repetibilidad ni frontera de estabilidad. No",
  "prescribas parámetros de corte nuevos."
].join("\n");

function ocultarClave(texto) {
  if (API_KEY && texto.includes(API_KEY)) return texto.split(API_KEY).join("[oculto]");
  return texto;
}

function textoRespuesta(datos) {
  const opciones = datos.choices || [];
  if (!opciones.length) return "";
  const mensaje = opciones[0].message || {};
  const contenido = mensaje.content;
  if (typeof contenido === "string") return contenido.trim();
  if (Array.isArray(contenido)) {
    return contenido.map((parte) => {
      if (typeof parte === "string") return parte;
      if (parte && parte.text) return parte.text;
      return "";
    }).join("\n").trim();
  }
  return "";
}

function consultarModelo(resumen) {
  if (!API_KEY) return Promise.reject(new Error("Falta LLM_API_KEY en el archivo .env"));
  const cuerpo = JSON.stringify({
    model: MODELO,
    max_completion_tokens: 2200,
    messages: [
      { role: "system", content: INSTRUCCION },
      {
        role: "user",
        content: "Aplica el criterio de contraste mayor que 4 y redacta el informe con las secciones indicadas. Usa exclusivamente estas cifras.\n" + JSON.stringify(resumen)
      }
    ]
  });
  const url = new URL(BASE_URL + "/chat/completions");
  return new Promise((resolve, reject) => {
    const solicitud = https.request({
      hostname: url.hostname,
      path: url.pathname,
      method: "POST",
      headers: {
        Authorization: "Bearer " + API_KEY,
        "Content-Type": "application/json",
        "Content-Length": Buffer.byteLength(cuerpo)
      },
      timeout: 120000
    }, (respuesta) => {
      const trozos = [];
      respuesta.on("data", (trozo) => trozos.push(trozo));
      respuesta.on("end", () => {
        const crudo = Buffer.concat(trozos).toString("utf8");
        if (respuesta.statusCode < 200 || respuesta.statusCode >= 300) {
          reject(new Error("El modelo respondió " + respuesta.statusCode + ": " + ocultarClave(crudo).slice(0, 800)));
          return;
        }
        let datos;
        try {
          datos = JSON.parse(crudo);
        } catch (error) {
          reject(new Error("El modelo devolvió una respuesta que no es JSON."));
          return;
        }
        const texto = textoRespuesta(datos);
        if (!texto) {
          reject(new Error("El modelo no devolvió texto."));
          return;
        }
        resolve(texto);
      });
    });
    solicitud.on("timeout", () => {
      solicitud.destroy(new Error("timeout"));
    });
    solicitud.on("error", (error) => {
      reject(new Error("No se pudo contactar el modelo: " + ocultarClave(error.message)));
    });
    solicitud.write(cuerpo);
    solicitud.end();
  });
}

function profundidadDeNombre(nombre) {
  const coincidencia = String(nombre).match(/(\d+(?:\.\d+)?)\s*mm/i);
  return coincidencia ? Number(coincidencia[1]) : null;
}

function archivosLvm(carpeta, prefijo) {
  if (!fs.existsSync(carpeta) || !fs.statSync(carpeta).isDirectory()) return [];
  const patron = new RegExp("^" + prefijo.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + "_*([0-9]+)\\.lvm$", "i");
  return fs.readdirSync(carpeta)
    .filter((nombre) => patron.test(nombre) && fs.statSync(path.join(carpeta, nombre)).isFile())
    .sort((a, b) => Number(a.match(patron)[1]) - Number(b.match(patron)[1]));
}

function sinAcento(texto) {
  return String(texto)
    .replace(/á/gi, "a").replace(/é/gi, "e").replace(/í/gi, "i")
    .replace(/ó/gi, "o").replace(/ú/gi, "u").replace(/ñ/gi, "n");
}

function hojasConLvm(raiz, prefijo) {
  const hojas = [];
  function recorrer(dir) {
    if (!fs.existsSync(dir) || !fs.statSync(dir).isDirectory()) return;
    const lista = archivosLvm(dir, prefijo);
    if (lista.length) hojas.push({ nombre: path.basename(dir), ruta: dir, archivos: lista });
    for (const entrada of fs.readdirSync(dir, { withFileTypes: true })) {
      if (entrada.isDirectory()) recorrer(path.join(dir, entrada.name));
    }
  }
  recorrer(raiz);
  return hojas;
}

function textoCondicion(nombre) {
  return sinAcento(nombre).toLowerCase().replace(/prueba\s*2[.,]0/g, " ");
}

function profundidadNominal(nombre) {
  const texto = textoCondicion(nombre);
  const conUnidad = texto.match(/(\d+(?:[.,]\d+)?)\s*mm/);
  if (conUnidad) {
    const valor = parseFloat(conUnidad[1].replace(",", "."));
    if (valor >= 1 && valor !== 2) return valor;
  }
  const suelta = texto.match(/\b(2[.,]5|1[.,]5|1|3|4)\b/);
  return suelta ? parseFloat(suelta[1].replace(",", ".")) : 2.5;
}

function herramientaDe(nombre) {
  const texto = textoCondicion(nombre);
  if (/desgast/.test(texto)) return "Desgastada";
  if (/nuev[oa]/.test(texto)) return "Nueva";
  return "";
}

function fluidoDe(nombre) {
  const texto = textoCondicion(nombre);
  if (/sin\s+(refrigerante|agua)/.test(texto)) return "Sin refrigerante";
  if (/refrigerante/.test(texto)) return "Con refrigerante";
  if (/agua/.test(texto)) return "Con agua";
  return "Sin refrigerante";
}

// Hora de grabación que LabVIEW guarda en el encabezado del primer .lvm de la carpeta.
// Aceleración y fuerza de un mismo ensayo se graban con 1 o 2 s de diferencia, así que
// sirve para emparejarlas aunque los nombres de carpeta no coincidan.
function horaDeHoja(hoja) {
  const primero = path.join(hoja.ruta, hoja.archivos[0]);
  try {
    const lineas = fs.readFileSync(primero, "utf8").split(/\r?\n/).slice(0, 80);
    const fecha = (lineas.find((l) => /^Date\t/.test(l)) || "").split("\t")[1];
    const hora = (lineas.find((l) => /^Time\t/.test(l)) || "").split("\t")[1];
    if (fecha && hora) {
      const [a, m, d] = fecha.split("/").map(Number);
      const [hh, mm, ss] = hora.split(":");
      return new Date(a, m - 1, d, Number(hh), Number(mm), parseFloat(ss.slice(0, 2))).getTime() / 1000;
    }
  } catch (error) {}
  return fs.statSync(primero).mtimeMs / 1000;
}

const TOLERANCIA_PAREJA_S = 120;
const ORDINALES = ["primera", "segunda", "tercera", "cuarta", "quinta", "sexta", "séptima", "octava", "novena", "décima"];

function emparejarPorHora(aceleracion, fuerza) {
  const candidatos = [];
  aceleracion.forEach((a, i) => fuerza.forEach((f, j) => {
    const d = Math.abs(a.hora - f.hora);
    if (d <= TOLERANCIA_PAREJA_S) candidatos.push({ i, j, d });
  }));
  candidatos.sort((x, y) => x.d - y.d);
  const usadasA = new Set();
  const usadasF = new Set();
  const parejas = [];
  for (const c of candidatos) {
    if (usadasA.has(c.i) || usadasF.has(c.j)) continue;
    usadasA.add(c.i);
    usadasF.add(c.j);
    parejas.push({ aceleracion: aceleracion[c.i], fuerza: fuerza[c.j] });
  }
  aceleracion.forEach((a, i) => { if (!usadasA.has(i)) parejas.push({ aceleracion: a, fuerza: null }); });
  fuerza.forEach((f, j) => { if (!usadasF.has(j)) parejas.push({ aceleracion: null, fuerza: f }); });
  return parejas;
}

function nombreDePrueba(herramienta, refrigerante, profundidad, ordinal) {
  return herramienta + ", " + String(profundidad).replace(/\.0$/, "") + " mm, " + refrigerante.toLowerCase() + ", " + ordinal + " prueba";
}

// Todas las carpetas con .lvm son una prueba. Se agrupan por herramienta y fluido y la
// repetición sale del orden de grabación (primera, segunda, tercera...).
function catalogoPrecargados() {
  const aceleracion = hojasConLvm(path.join(RAIZ, "Aceleración"), "A").map((h) => ({ ...h, hora: horaDeHoja(h) }));
  const fuerza = hojasConLvm(path.join(RAIZ, "Fuerza"), "F").map((h) => ({ ...h, hora: horaDeHoja(h) }));
  const modal = hojasConLvm(path.join(RAIZ, "Analisis modal"), "A");
  const modalHoja = modal[0] || { ruta: "", archivos: [] };

  const ensayos = emparejarPorHora(aceleracion, fuerza).map((par) => {
    const base = par.aceleracion || par.fuerza;
    return {
      par,
      hora: base.hora,
      herramienta: herramientaDe(base.nombre) || herramientaDe((par.fuerza || base).nombre) || "Nueva",
      refrigerante: fluidoDe(base.nombre),
      profundidad: profundidadNominal(base.nombre)
    };
  });
  ensayos.sort((a, b) => a.hora - b.hora);

  const contador = new Map();
  const pruebas = ensayos.map((e) => {
    const grupo = e.herramienta + "|" + e.refrigerante + "|" + e.profundidad;
    const n = (contador.get(grupo) || 0) + 1;
    contador.set(grupo, n);
    const ordinal = ORDINALES[n - 1] || (n + "ª");
    const slug = (e.refrigerante === "Con agua" ? "agua" : (e.refrigerante === "Con refrigerante" ? "con" : "sin"));
    const A = e.par.aceleracion;
    const F = e.par.fuerza;
    return {
      id: [e.herramienta === "Desgastada" ? "desgastada" : "nueva", slug, e.profundidad.toFixed(1), n].join("|"),
      nombre: nombreDePrueba(e.herramienta, e.refrigerante, e.profundidad, ordinal),
      profundidad_mm: e.profundidad,
      herramienta: e.herramienta,
      refrigerante: e.refrigerante,
      repeticion: ordinal,
      carpetaAceleracion: A ? A.nombre : "",
      carpetaFuerza: F ? F.nombre : "",
      rutaAceleracion: A ? A.ruta : "",
      rutaFuerza: F ? F.ruta : "",
      rutaModal: modalHoja.ruta,
      archivos_aceleracion: A ? A.archivos : [],
      archivos_fuerza: F ? F.archivos : [],
      archivos_modal: modalHoja.archivos
    };
  });
  const orden = { Nueva: 0, Desgastada: 1 };
  const fluido = { "Sin refrigerante": 0, "Con refrigerante": 1, "Con agua": 2 };
  return pruebas.sort((a, b) =>
    (orden[a.herramienta] - orden[b.herramienta]) ||
    (fluido[a.refrigerante] - fluido[b.refrigerante]) ||
    (ORDINALES.indexOf(a.repeticion) - ORDINALES.indexOf(b.repeticion)));
}

// Versión estática (rutas relativas) para datos/catalogo.json. Se genera con:
//   node servidor_chatter.js --catalogo
function catalogoEstatico() {
  const rel = (ruta, nombres) => nombres.map((n) => path.relative(RAIZ, path.join(ruta, n)).split(path.sep).join("/"));
  return {
    pruebas: catalogoPrecargados().map((p) => ({
      id: p.id,
      nombre: p.nombre,
      profundidad_mm: p.profundidad_mm,
      herramienta: p.herramienta,
      refrigerante: p.refrigerante,
      repeticion: p.repeticion,
      carpeta_aceleracion: p.carpetaAceleracion,
      carpeta_fuerza: p.carpetaFuerza,
      aceleracion: rel(p.rutaAceleracion, p.archivos_aceleracion),
      fuerza: rel(p.rutaFuerza, p.archivos_fuerza),
      modal: rel(p.rutaModal, p.archivos_modal)
    }))
  };
}

function leerArchivos(carpeta, nombres) {
  return nombres.map((nombre) => {
    let texto = fs.readFileSync(path.join(carpeta, nombre), "utf8");
    if (texto.charCodeAt(0) === 0xfeff) texto = texto.slice(1);
    return { nombre, texto };
  });
}

function datosPrecargados(id) {
  const prueba = catalogoPrecargados().find((item) => item.id === id || String(item.profundidad_mm) === String(id));
  if (!prueba) throw new Error("No hay datos precargados para esa prueba.");
  return {
    nombre: prueba.nombre,
    aceleracion: prueba.rutaAceleracion ? leerArchivos(prueba.rutaAceleracion, prueba.archivos_aceleracion) : [],
    fuerza: prueba.rutaFuerza ? leerArchivos(prueba.rutaFuerza, prueba.archivos_fuerza) : [],
    modal: prueba.rutaModal ? leerArchivos(prueba.rutaModal, prueba.archivos_modal) : []
  };
}

const TIPOS = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".svg": "image/svg+xml",
  ".css": "text/css; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".png": "image/png"
};

function enviar(respuesta, codigo, cuerpo, tipo) {
  const buffer = Buffer.isBuffer(cuerpo) ? cuerpo : Buffer.from(cuerpo);
  respuesta.writeHead(codigo, {
    "Content-Type": tipo || "text/plain; charset=utf-8",
    "Content-Length": buffer.length,
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "Content-Type",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS"
  });
  respuesta.end(buffer);
}

function enviarJson(respuesta, codigo, datos) {
  enviar(respuesta, codigo, JSON.stringify(datos), "application/json; charset=utf-8");
}

const RAICES_DATOS = {
  aceleracion: path.join(RAIZ, "Aceleración"),
  fuerza: path.join(RAIZ, "Fuerza")
};

const TABLA_CRC = (() => {
  const tabla = new Uint32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = (c & 1) ? (0xedb88320 ^ (c >>> 1)) : (c >>> 1);
    tabla[n] = c >>> 0;
  }
  return tabla;
})();

function crc32(buffer) {
  let c = 0xffffffff;
  for (let i = 0; i < buffer.length; i++) c = TABLA_CRC[(c ^ buffer[i]) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}

function u16(n) {
  const b = Buffer.alloc(2);
  b.writeUInt16LE(n & 0xffff);
  return b;
}

function u32(n) {
  const b = Buffer.alloc(4);
  b.writeUInt32LE(n >>> 0);
  return b;
}

function fechaDos(fecha) {
  const time = (fecha.getHours() << 11) | (fecha.getMinutes() << 5) | Math.floor(fecha.getSeconds() / 2);
  const date = ((fecha.getFullYear() - 1980) << 9) | ((fecha.getMonth() + 1) << 5) | fecha.getDate();
  return { time, date };
}

function encabezadoAdjunto(nombre) {
  const ascii = String(nombre).replace(/[^\x20-\x7E]/g, "_").replace(/["\\]/g, "_");
  return "attachment; filename=\"" + ascii + "\"; filename*=UTF-8''" + encodeURIComponent(nombre);
}

function cabecerasDescarga(extra) {
  return Object.assign({
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "Content-Type",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS"
  }, extra);
}

function escribir(respuesta, buffer) {
  return new Promise((resolve, reject) => {
    respuesta.write(buffer, (error) => (error ? reject(error) : resolve()));
  });
}

function comprimir(datos) {
  return new Promise((resolve, reject) => {
    zlib.deflateRaw(datos, { level: 1 }, (error, salida) => (error ? reject(error) : resolve(salida)));
  });
}

function ensayosDe(tipo) {
  const raiz = RAICES_DATOS[tipo];
  const prefijo = tipo === "fuerza" ? "F" : "A";
  return hojasConLvm(raiz, prefijo).map((hoja) => {
    const archivos = hoja.archivos.map((nombre) => ({
      nombre,
      bytes: fs.statSync(path.join(hoja.ruta, nombre)).size
    }));
    return {
      id: path.relative(raiz, hoja.ruta).split(path.sep).join("/"),
      nombre: hoja.nombre,
      archivos,
      bytes: archivos.reduce((suma, archivo) => suma + archivo.bytes, 0)
    };
  }).sort((a, b) => a.nombre.localeCompare(b.nombre, "es"));
}

function entradasDe(tipo, id) {
  const ensayos = ensayosDe(tipo);
  const elegidos = id ? ensayos.filter((ensayo) => ensayo.id === id) : ensayos;
  if (id && !elegidos.length) return null;
  const raiz = path.resolve(RAICES_DATOS[tipo]);
  const entradas = [];
  for (const ensayo of elegidos) {
    const carpeta = path.resolve(raiz, ...ensayo.id.split("/"));
    if (carpeta !== raiz && !carpeta.startsWith(raiz + path.sep)) continue;
    for (const archivo of ensayo.archivos) {
      const ruta = path.resolve(carpeta, archivo.nombre);
      if (!ruta.startsWith(carpeta + path.sep)) continue;
      const relativo = (id ? archivo.nombre : ensayo.id + "/" + archivo.nombre).replace(/\\/g, "/");
      entradas.push({ ruta, nombre: relativo });
    }
  }
  return entradas;
}

function nombreDelZip(tipo, id) {
  if (tipo === "ambos") return "aceleracion-y-fuerza.zip";
  if (!id) return tipo + ".zip";
  const base = id.split("/").pop() || tipo;
  const limpio = base.replace(/[\\/:*?"<>|]+/g, " ").replace(/\s+/g, " ").trim() || tipo;
  return limpio + ".zip";
}

async function enviarZip(respuesta, entradas, nombreDescarga, prefijo) {
  const fecha = fechaDos(new Date());
  respuesta.writeHead(200, cabecerasDescarga({
    "Content-Type": "application/zip",
    "Content-Disposition": encabezadoAdjunto(nombreDescarga)
  }));
  const centrales = [];
  let offset = 0;
  for (const entrada of entradas) {
    const datos = await fs.promises.readFile(entrada.ruta);
    const comp = await comprimir(datos);
    const crc = crc32(datos);
    const nombre = Buffer.from((prefijo ? prefijo + "/" : "") + entrada.nombre, "utf8");
    const local = Buffer.concat([
      u32(0x04034b50), u16(20), u16(0x800), u16(8),
      u16(fecha.time), u16(fecha.date), u32(crc), u32(comp.length), u32(datos.length),
      u16(nombre.length), u16(0), nombre, comp
    ]);
    const central = Buffer.concat([
      u32(0x02014b50), u16(20), u16(20), u16(0x800), u16(8),
      u16(fecha.time), u16(fecha.date), u32(crc), u32(comp.length), u32(datos.length),
      u16(nombre.length), u16(0), u16(0), u16(0), u16(0), u32(0), u32(offset), nombre
    ]);
    await escribir(respuesta, local);
    offset += local.length;
    centrales.push(central);
  }
  const directorio = Buffer.concat(centrales);
  const cierre = Buffer.concat([
    u32(0x06054b50), u16(0), u16(0), u16(centrales.length), u16(centrales.length),
    u32(directorio.length), u32(offset), u16(0)
  ]);
  await escribir(respuesta, directorio);
  await escribir(respuesta, cierre);
  respuesta.end();
}

function enviarAdjunto(respuesta, ruta, nombre) {
  const datos = fs.readFileSync(ruta);
  respuesta.writeHead(200, cabecerasDescarga({
    "Content-Type": "application/octet-stream",
    "Content-Length": datos.length,
    "Content-Disposition": encabezadoAdjunto(nombre)
  }));
  respuesta.end(datos);
}

async function servirDescarga(url, respuesta) {
  const tipo = url.searchParams.get("tipo") || "";
  const id = url.searchParams.get("id") || "";
  const archivo = url.searchParams.get("archivo") || "";
  if (tipo !== "aceleracion" && tipo !== "fuerza" && tipo !== "ambos") {
    enviarJson(respuesta, 400, { error: "El tipo debe ser aceleracion, fuerza o ambos." });
    return;
  }
  if (archivo && (archivo !== path.basename(archivo) || !/\.lvm$/i.test(archivo))) {
    enviarJson(respuesta, 400, { error: "Archivo no permitido." });
    return;
  }
  if (tipo === "ambos" && (id || archivo)) {
    enviarJson(respuesta, 400, { error: "La descarga completa no admite un ensayo o archivo suelto." });
    return;
  }
  if (id && id.split(/[\\/]/).some((parte) => !parte || parte === "." || parte === "..")) {
    enviarJson(respuesta, 400, { error: "Ensayo no permitido." });
    return;
  }
  const tipos = tipo === "ambos" ? ["aceleracion", "fuerza"] : [tipo];
  let entradas = [];
  for (const actual of tipos) {
    const delTipo = entradasDe(actual, id);
    if (delTipo === null) {
      enviarJson(respuesta, 404, { error: "No está ese ensayo." });
      return;
    }
    const prefijo = tipo === "ambos" ? actual : "";
    entradas = entradas.concat(delTipo.map((entrada) => ({
      ruta: entrada.ruta,
      nombre: prefijo ? prefijo + "/" + entrada.nombre : entrada.nombre
    })));
  }
  if (archivo) {
    const encontrada = entradas.find((entrada) => path.posix.basename(entrada.nombre) === archivo);
    if (!encontrada) {
      enviarJson(respuesta, 404, { error: "No está ese archivo." });
      return;
    }
    enviarAdjunto(respuesta, encontrada.ruta, archivo);
    return;
  }
  if (!entradas.length) {
    enviarJson(respuesta, 404, { error: "No hay archivos para descargar." });
    return;
  }
  await enviarZip(respuesta, entradas, nombreDelZip(tipo, id), "");
}

function servirArchivo(respuesta, ruta) {
  const contenido = fs.readFileSync(ruta);
  enviar(respuesta, 200, contenido, TIPOS[path.extname(ruta).toLowerCase()] || "application/octet-stream");
}

function rutaSegura(base, relativo) {
  const completa = path.resolve(base, relativo);
  const raiz = path.resolve(base);
  if (completa !== raiz && !completa.startsWith(raiz + path.sep)) return null;
  return completa;
}

const servidor = http.createServer((peticion, respuesta) => {
  const url = new URL(peticion.url, "http://127.0.0.1");
  const ruta = decodeURIComponent(url.pathname);

  if (peticion.method === "OPTIONS") {
    enviar(respuesta, 204, "");
    return;
  }

  if (peticion.method === "GET") {
    if (ruta === "/api/descargas") {
      enviarJson(respuesta, 200, {
        aceleracion: ensayosDe("aceleracion"),
        fuerza: ensayosDe("fuerza")
      });
      return;
    }
    if (ruta === "/api/descargar") {
      servirDescarga(url, respuesta).catch((error) => {
        if (!respuesta.headersSent) enviarJson(respuesta, 500, { error: error.message || String(error) });
        else respuesta.end();
      });
      return;
    }
    if (ruta === "/api/datos-precargados") {
      enviarJson(respuesta, 200, {
        pruebas: catalogoPrecargados().map((prueba) => ({
          id: prueba.id,
          nombre: prueba.nombre,
          profundidad_mm: prueba.profundidad_mm,
          herramienta: prueba.herramienta,
          refrigerante: prueba.refrigerante,
          repeticion: prueba.repeticion
        }))
      });
      return;
    }
    const paginas = new Set(["", "/", "/index.html", "/pagina", "/pagina/", "/pagina/index.html"]);
    const recursos = {
      "/Analisis de chatter.html": "Analisis de chatter.html",
      "/analisis.js": "analisis.js",
      "/logo-tec.svg": "logo-tec.svg"
    };
    if (paginas.has(ruta)) {
      servirArchivo(respuesta, path.join(RAIZ, "Analisis de chatter.html"));
      return;
    }
    if (recursos[ruta]) {
      servirArchivo(respuesta, path.join(RAIZ, recursos[ruta]));
      return;
    }
    const relativa = ruta.replace(/^\/+/, "");
    const enPagina = rutaSegura(PAGINA, relativa);
    if (enPagina && fs.existsSync(enPagina) && fs.statSync(enPagina).isFile()) {
      servirArchivo(respuesta, enPagina);
      return;
    }
    enviar(respuesta, 404, "No encontrado");
    return;
  }

  if (peticion.method === "POST" && (ruta === "/api/interpretar" || ruta === "/api/datos-precargados")) {
    const trozos = [];
    let total = 0;
    peticion.on("data", (trozo) => {
      total += trozo.length;
      if (total <= 1_000_000) trozos.push(trozo);
    });
    peticion.on("end", async () => {
      try {
        const resumen = JSON.parse(Buffer.concat(trozos).toString("utf8") || "{}");
        if (ruta === "/api/datos-precargados") {
          enviarJson(respuesta, 200, datosPrecargados(resumen.id || resumen.profundidad_mm));
          return;
        }
        const texto = await consultarModelo(resumen);
        enviarJson(respuesta, 200, { texto });
      } catch (error) {
        enviarJson(respuesta, 502, { error: ocultarClave(error.message || String(error)) });
      }
    });
    return;
  }

  enviar(respuesta, 404, "No encontrado");
});

if (!fs.existsSync(PAGINA)) {
  console.error("No está la carpeta pagina.");
  process.exit(1);
}

if (process.argv.includes("--catalogo")) {
  const destino = path.join(RAIZ, "datos", "catalogo.json");
  fs.mkdirSync(path.dirname(destino), { recursive: true });
  const catalogo = catalogoEstatico();
  fs.writeFileSync(destino, JSON.stringify(catalogo, null, 2) + "\n", "utf8");
  console.log("datos/catalogo.json actualizado con " + catalogo.pruebas.length + " pruebas:");
  catalogo.pruebas.forEach((p) => console.log(" - " + p.nombre + " (A: " + p.aceleracion.length + ", F: " + p.fuerza.length + ")"));
  process.exit(0);
}

servidor.listen(PUERTO, "127.0.0.1", () => {
  console.log("Análisis de chatter en http://127.0.0.1:" + PUERTO);
  console.log("Modelo: " + MODELO);
  console.log("Clave cargada: " + (API_KEY ? "sí" : "no"));
});
