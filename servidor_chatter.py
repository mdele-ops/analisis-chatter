# Servidor local del análisis de chatter.
# La clave se lee solo desde .env y no se envía al navegador.

import json
import os
import re
import ssl
import urllib.error
import urllib.request
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import unquote, urlsplit

RAIZ = os.path.dirname(os.path.abspath(__file__))
PAGINA = os.path.join(RAIZ, "pagina")


def leer_env(ruta):
    valores = {}
    if not os.path.isfile(ruta):
        return valores
    with open(ruta, "r", encoding="utf-8") as archivo:
        for linea in archivo:
            linea = linea.strip()
            if not linea or linea.startswith("#") or "=" not in linea:
                continue
            clave, valor = linea.split("=", 1)
            valores[clave.strip()] = valor.strip().strip('"').strip("'")
    return valores


ENV = leer_env(os.path.join(RAIZ, ".env"))
API_KEY = ENV.get("LLM_API_KEY", "")
BASE_URL = ENV.get("LLM_BASE_URL", "https://llm-stage.gm.com/v1").rstrip("/")
MODELO = ENV.get("LLM_MODEL", "gpt-5.4-mini")
PUERTO = int(ENV.get("PORT", "3000"))

INSTRUCCION = (
    "Eres especialista en vibraciones y chatter en torneado. Redactas un informe técnico en español formal "
    "a partir de un resumen calculado por software. No recibes señales crudas ni gráficas: no afirmes haberlas "
    "inspeccionado. No inventes cifras, picos, causas ni resultados. Si un campo es null, falta o hay error, "
    "trátalo como no disponible. Distingue dato medido, inferencia y recomendación.\n\n"
    "CRITERIOS\n"
    "La máquina reporta 720 rpm, equivalentes a 12 Hz de giro, y un avance de 32 mm/in. Conserva esa unidad; "
    "no la conviertas ni supongas otra convención. La banda es la frecuencia natural ± 125 Hz; si no hay modal, "
    "1300-1550 Hz. Hay indicio en un eje solo cuando su contraste, pico en banda dividido entre la mediana del "
    "espectro de 100 a 3000 Hz fuera de la banda, es mayor que 4. Contraste menor o igual a 4 no activa el "
    "detector en ese eje. Es un indicador heurístico, no confirmación de chatter autoexcitado. Si la mediana "
    "está cerca de cero, no describas el cociente como magnitud física: el fondo es muy pequeño y la razón es "
    "inestable. Coincidir con la frecuencia natural es compatible con resonancia y no prueba chatter "
    "autoexcitado. No atribuyas el origen a los 12 Hz de giro sin evidencia en el resumen. El índice es relativo: "
    "menor es más favorable, con vibración 45%, amplitud modal 35% y fuerza 20%, y suma 0.15 si el detector "
    "marca indicio. No es probabilidad ni frontera de estabilidad. Distingue el RMS resultante global del RMS "
    "por eje.\n\n"
    "INFORME\n"
    "Entre 350 y 475 palabras. Encabezados en texto plano, sin numerales ni asteriscos. Evita paréntesis salvo "
    "que sean imprescindibles. Secciones exactas: Dictamen; Método; Hallazgos por espesor; Comparación e "
    "interpretación; Recomendaciones y limitaciones.\n"
    "Dictamen: cuántos ensayos activan el detector y una confianza cualitativa, en una o dos frases.\n"
    "Método: frecuencia natural, banda, umbral 4, frecuencias de muestreo y unidades, en dos frases como máximo.\n"
    "Hallazgos por espesor: dos frases por espesor. Di si el detector se activa, qué ejes superan 4 y solo las "
    "cifras que sostienen eso: contraste y pico en banda de los ejes decisivos, RMS global de aceleración, RMS "
    "global de fuerza, crecimiento fin/inicio e índice. Como máximo uno o dos picos representativos. Menciona "
    "datos ausentes solo si cambian la conclusión.\n"
    "Comparación: ordena por índice y describe la tendencia sin causalidad. Si hay una sola prueba, no inventes "
    "comparaciones.\n"
    "Recomendaciones: dos acciones de validación. No infieras repetibilidad ni frontera de estabilidad. No "
    "prescribas parámetros de corte nuevos."
)


def ocultar_clave(texto):
    if API_KEY and API_KEY in texto:
        return texto.replace(API_KEY, "[oculto]")
    return texto


def texto_respuesta(datos):
    opciones = datos.get("choices") or []
    if not opciones:
        return ""
    mensaje = opciones[0].get("message") or {}
    contenido = mensaje.get("content")
    if isinstance(contenido, str):
        return contenido.strip()
    if isinstance(contenido, list):
        partes = []
        for parte in contenido:
            if isinstance(parte, str):
                partes.append(parte)
            elif isinstance(parte, dict) and parte.get("text"):
                partes.append(parte["text"])
        return "\n".join(partes).strip()
    return ""


def consultar_modelo(resumen):
    if not API_KEY:
        raise RuntimeError("Falta LLM_API_KEY en el archivo .env")
    cuerpo = {
        "model": MODELO,
        "max_completion_tokens": 2200,
        "messages": [
            {"role": "system", "content": INSTRUCCION},
            {
                "role": "user",
                "content": (
                    "Aplica el criterio de contraste mayor que 4 y redacta el informe con las secciones indicadas. "
                    "Usa exclusivamente estas cifras.\n"
                    + json.dumps(resumen, ensure_ascii=False)
                ),
            },
        ],
    }
    solicitud = urllib.request.Request(
        BASE_URL + "/chat/completions",
        data=json.dumps(cuerpo).encode("utf-8"),
        headers={
            "Authorization": "Bearer " + API_KEY,
            "Content-Type": "application/json",
        },
        method="POST",
    )
    contexto = ssl.create_default_context()
    try:
        with urllib.request.urlopen(solicitud, timeout=120, context=contexto) as respuesta:
            datos = json.loads(respuesta.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        detalle = error.read().decode("utf-8", errors="replace")
        raise RuntimeError("El modelo respondió %s: %s" % (error.code, ocultar_clave(detalle)[:800]))
    except urllib.error.URLError as error:
        raise RuntimeError("No se pudo contactar el modelo: %s" % ocultar_clave(str(error.reason)))
    texto = texto_respuesta(datos)
    if not texto:
        raise RuntimeError("El modelo no devolvió texto.")
    return texto


def profundidad_de_nombre(nombre):
    coincidencia = re.search(r"(\d+(?:\.\d+)?)\s*mm", nombre, re.IGNORECASE)
    return float(coincidencia.group(1)) if coincidencia else None


def archivos_lvm(carpeta, prefijo):
    if not os.path.isdir(carpeta):
        return []
    archivos = []
    for nombre in os.listdir(carpeta):
        coincidencia = re.match(r"%s_*([0-9]+)\.lvm$" % re.escape(prefijo), nombre, re.IGNORECASE)
        if coincidencia and os.path.isfile(os.path.join(carpeta, nombre)):
            archivos.append((int(coincidencia.group(1)), nombre))
    return [nombre for _, nombre in sorted(archivos)]


def catalogo_precargados():
    raiz_aceleracion = os.path.join(RAIZ, "Aceleración")
    raiz_fuerza = os.path.join(RAIZ, "Fuerza")
    raiz_modal = os.path.join(RAIZ, "Analisis modal", "Analisis modal")
    carpetas_fuerza = {}
    if os.path.isdir(raiz_fuerza):
        for nombre in os.listdir(raiz_fuerza):
            profundidad = profundidad_de_nombre(nombre)
            if profundidad is not None and os.path.isdir(os.path.join(raiz_fuerza, nombre)):
                carpetas_fuerza.setdefault(profundidad, []).append(nombre)

    pruebas = []
    if os.path.isdir(raiz_aceleracion):
        for nombre in os.listdir(raiz_aceleracion):
            profundidad = profundidad_de_nombre(nombre)
            carpeta_a = os.path.join(raiz_aceleracion, nombre)
            carpetas_f = carpetas_fuerza.get(profundidad, []) if profundidad is not None else []
            if profundidad is None or not os.path.isdir(carpeta_a) or len(carpetas_f) != 1:
                continue
            carpeta_f = os.path.join(raiz_fuerza, carpetas_f[0])
            lista_a = archivos_lvm(carpeta_a, "A")
            lista_f = archivos_lvm(carpeta_f, "F")
            lista_m = archivos_lvm(raiz_modal, "A")
            if lista_a and lista_f:
                pruebas.append({
                    "profundidad_mm": profundidad,
                    "nombre": nombre,
                    "archivos_aceleracion": lista_a,
                    "archivos_fuerza": lista_f,
                    "archivos_modal": lista_m,
                })
    return sorted(pruebas, key=lambda prueba: prueba["profundidad_mm"])


def datos_precargados(profundidad):
    prueba = next(
        (item for item in catalogo_precargados() if item["profundidad_mm"] == profundidad),
        None,
    )
    if prueba is None:
        raise ValueError("No hay datos precargados para ese espesor.")

    def leer_archivos(carpeta, nombres):
        salida = []
        for nombre in nombres:
            ruta = os.path.join(carpeta, nombre)
            with open(ruta, "r", encoding="utf-8-sig") as archivo:
                salida.append({"nombre": nombre, "texto": archivo.read()})
        return salida

    carpeta_fuerza = next(
        nombre for nombre in os.listdir(os.path.join(RAIZ, "Fuerza"))
        if profundidad_de_nombre(nombre) == profundidad
        and os.path.isdir(os.path.join(RAIZ, "Fuerza", nombre))
    )
    return {
        "nombre": prueba["nombre"],
        "aceleracion": leer_archivos(
            os.path.join(RAIZ, "Aceleración", prueba["nombre"]),
            prueba["archivos_aceleracion"],
        ),
        "fuerza": leer_archivos(
            os.path.join(RAIZ, "Fuerza", carpeta_fuerza),
            prueba["archivos_fuerza"],
        ),
        "modal": leer_archivos(
            os.path.join(RAIZ, "Analisis modal", "Analisis modal"),
            prueba["archivos_modal"],
        ),
    }


class Manejador(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=PAGINA, **kwargs)

    def end_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        super().end_headers()

    def servir_recurso_raiz(self, nombre):
        ruta = os.path.join(RAIZ, nombre)
        with open(ruta, "rb") as archivo:
            contenido = archivo.read()
        self.send_response(200)
        self.send_header("Content-Type", self.guess_type(ruta))
        self.send_header("Content-Length", str(len(contenido)))
        self.end_headers()
        self.wfile.write(contenido)

    def do_GET(self):
        ruta = unquote(urlsplit(self.path).path)
        if ruta == "/api/datos-precargados":
            cuerpo = json.dumps({"pruebas": catalogo_precargados()}, ensure_ascii=False).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(cuerpo)))
            self.end_headers()
            self.wfile.write(cuerpo)
            return
        paginas = {"", "/", "/index.html", "/pagina", "/pagina/", "/pagina/index.html"}
        recursos = {
            "/Analisis de chatter.html": "Analisis de chatter.html",
            "/analisis.js": "analisis.js",
            "/logo-tec.svg": "logo-tec.svg",
            "/ejemplo.html": "ejemplo.html",
        }
        if ruta in paginas:
            self.servir_recurso_raiz("Analisis de chatter.html")
            return
        nombre = recursos.get(ruta)
        if nombre:
            self.servir_recurso_raiz(nombre)
            return
        super().do_GET()

    def do_OPTIONS(self):
        self.send_response(204)
        self.end_headers()

    def do_POST(self):
        ruta = self.path.split("?", 1)[0]
        if ruta not in {"/api/interpretar", "/api/datos-precargados"}:
            self.send_error(404)
            return
        try:
            longitud = int(self.headers.get("Content-Length", "0"))
            crudo = self.rfile.read(min(longitud, 1_000_000))
            resumen = json.loads(crudo.decode("utf-8"))
            if ruta == "/api/datos-precargados":
                datos = datos_precargados(float(resumen.get("profundidad_mm", -1)))
                cuerpo = json.dumps(datos, ensure_ascii=False).encode("utf-8")
            else:
                texto = consultar_modelo(resumen)
                cuerpo = json.dumps({"texto": texto}, ensure_ascii=False).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(cuerpo)))
            self.end_headers()
            self.wfile.write(cuerpo)
        except Exception as error:
            mensaje = ocultar_clave(str(error))
            cuerpo = json.dumps({"error": mensaje}, ensure_ascii=False).encode("utf-8")
            self.send_response(502)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(cuerpo)))
            self.end_headers()
            self.wfile.write(cuerpo)

    def log_message(self, formato, *args):
        linea = formato % args
        if API_KEY and API_KEY in linea:
            linea = linea.replace(API_KEY, "[oculto]")
        print("[%s] %s" % (self.log_date_time_string(), linea))


def main():
    if not os.path.isdir(PAGINA):
        raise SystemExit("No está la carpeta pagina.")
    servidor = ThreadingHTTPServer(("127.0.0.1", PUERTO), Manejador)
    print("Análisis de chatter en http://127.0.0.1:%s" % PUERTO)
    print("Modelo: %s" % MODELO)
    print("Clave cargada: %s" % ("sí" if API_KEY else "no"))
    servidor.serve_forever()


if __name__ == "__main__":
    main()
