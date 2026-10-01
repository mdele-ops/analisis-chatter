// Servidor local del análisis de chatter.
// La clave se lee solo desde .env y no se envía al navegador.
// Se arranca con: node servidor_chatter.js

const fs = require("fs");
const http = require("http");
const https = require("https");
const path = require("path");

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

function catalogoPrecargados() {
  const raizAceleracion = path.join(RAIZ, "Aceleración");
  const raizFuerza = path.join(RAIZ, "Fuerza");
  const raizModal = path.join(RAIZ, "Analisis modal", "Analisis modal");
  const carpetasFuerza = new Map();
  if (fs.existsSync(raizFuerza)) {
    for (const nombre of fs.readdirSync(raizFuerza)) {
      const profundidad = profundidadDeNombre(nombre);
      if (profundidad != null && fs.statSync(path.join(raizFuerza, nombre)).isDirectory()) {
        if (!carpetasFuerza.has(profundidad)) carpetasFuerza.set(profundidad, []);
        carpetasFuerza.get(profundidad).push(nombre);
      }
    }
  }
  const pruebas = [];
  if (fs.existsSync(raizAceleracion)) {
    for (const nombre of fs.readdirSync(raizAceleracion)) {
      const profundidad = profundidadDeNombre(nombre);
      const carpetaA = path.join(raizAceleracion, nombre);
      const carpetasF = profundidad == null ? [] : (carpetasFuerza.get(profundidad) || []);
      if (profundidad == null || !fs.existsSync(carpetaA) || !fs.statSync(carpetaA).isDirectory() || carpetasF.length !== 1) continue;
      const listaA = archivosLvm(carpetaA, "A");
      const listaF = archivosLvm(path.join(raizFuerza, carpetasF[0]), "F");
      const listaM = archivosLvm(raizModal, "A");
      if (listaA.length && listaF.length) {
        pruebas.push({
          profundidad_mm: profundidad,
          nombre,
          archivos_aceleracion: listaA,
          archivos_fuerza: listaF,
          archivos_modal: listaM
        });
      }
    }
  }
  return pruebas.sort((a, b) => a.profundidad_mm - b.profundidad_mm);
}

function leerArchivos(carpeta, nombres) {
  return nombres.map((nombre) => {
    let texto = fs.readFileSync(path.join(carpeta, nombre), "utf8");
    if (texto.charCodeAt(0) === 0xfeff) texto = texto.slice(1);
    return { nombre, texto };
  });
}

function datosPrecargados(profundidad) {
  const prueba = catalogoPrecargados().find((item) => item.profundidad_mm === profundidad);
  if (!prueba) throw new Error("No hay datos precargados para ese espesor.");
  const carpetaFuerza = fs.readdirSync(path.join(RAIZ, "Fuerza")).find((nombre) => {
    return profundidadDeNombre(nombre) === profundidad && fs.statSync(path.join(RAIZ, "Fuerza", nombre)).isDirectory();
  });
  return {
    nombre: prueba.nombre,
    aceleracion: leerArchivos(path.join(RAIZ, "Aceleración", prueba.nombre), prueba.archivos_aceleracion),
    fuerza: leerArchivos(path.join(RAIZ, "Fuerza", carpetaFuerza), prueba.archivos_fuerza),
    modal: leerArchivos(path.join(RAIZ, "Analisis modal", "Analisis modal"), prueba.archivos_modal)
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
    if (ruta === "/api/datos-precargados") {
      enviarJson(respuesta, 200, { pruebas: catalogoPrecargados() });
      return;
    }
    const paginas = new Set(["", "/", "/index.html", "/pagina", "/pagina/", "/pagina/index.html"]);
    const recursos = {
      "/Analisis de chatter.html": "Analisis de chatter.html",
      "/analisis.js": "analisis.js",
      "/logo-tec.svg": "logo-tec.svg",
      "/ejemplo.html": "ejemplo.html"
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
          enviarJson(respuesta, 200, datosPrecargados(Number(resumen.profundidad_mm)));
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

servidor.listen(PUERTO, "127.0.0.1", () => {
  console.log("Análisis de chatter en http://127.0.0.1:" + PUERTO);
  console.log("Modelo: " + MODELO);
  console.log("Clave cargada: " + (API_KEY ? "sí" : "no"));
});
