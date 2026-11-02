"use strict";
/* Genera las gráficas de fuerza, vibración y rugosidad (señal temporal, RMS y FFT)
   usando los datos .lvm del proyecto y el mismo analisis.js de la página.
   Uso:  cd graficas  &&  node generar_graficas.js        (salida: graficas/salida/*.png) */

const fs = require("fs");
const path = require("path");
const { createCanvas } = require("@napi-rs/canvas");

const RAIZ = path.resolve(__dirname, "..");
const SALIDA = path.join(__dirname, "salida");
fs.mkdirSync(SALIDA, { recursive: true });

require(path.join(RAIZ, "analisis.js"));
const CA = globalThis.ChatterAnalisis;

/* Rugosidad medida sobre la pieza (mismos valores que la página) */
const PIEZA = {
  "1": { dIni: 52.16, dFin: 50.53, ra: [0.96, 1.13, 1.26, 1.49, 1.35] },
  "1.5": { dIni: 52.02, dFin: 48.43, ra: [3.23, 4.41, 3.96, 3.8, 4.88] },
  "2": { dIni: 52.14, dFin: 48.02, ra: [5.6, 5.73, 5.8, 6.5, 5.86] },
  "2.5": { dIni: 52.04, dFin: 46.96, ra: [5.37, 5.68, 5.49, 5.28, 5.12] }
};
const RPM = 720;
const F_HUSILLO = RPM / 60; // 12 Hz

const COL_PROF = ["#2a9d8f", "#e9c46a", "#f4802a", "#d62839"];
const COL_EJE = ["#1d6fd1", "#2a9d3f", "#d62839"];
const EJES = ["X", "Y", "Z"];
const FUENTE = "Arial, 'Segoe UI', sans-serif";

/* ---------- lectura de datos ---------- */
function leerGrupo(rutas, ejeUnico) {
  const leidos = rutas.map((r) => {
    const abs = path.join(RAIZ, r);
    const texto = fs.readFileSync(abs, "utf8");
    return { nombre: path.basename(r), orden: CA.ordenArchivo(r), eje: CA.ejeDeRuta(r), datos: CA.parseLVM(texto, r) };
  });
  return CA.armarXYZ(leidos, ejeUnico);
}

function tarar(col) {
  const n = Math.min(1000, Math.max(1, Math.floor(col.length * 0.1)));
  let s = 0;
  for (let i = 0; i < n; i++) s += col[i];
  const m = s / n;
  return Float64Array.from(col, (v) => v - m);
}

const cat = JSON.parse(fs.readFileSync(path.join(RAIZ, "datos", "catalogo.json"), "utf8"));
const pruebas = cat.pruebas.map((c) => {
  const modal = CA.analizarModal(leerGrupo(c.modal, "X"), 0);
  const aArm = leerGrupo(c.aceleracion, "X");
  const fArm = leerGrupo(c.fuerza, "X");
  const aRes = CA.analizarSenal(aArm, modal.banda);
  const fRes = CA.analizarSenal(fArm, modal.banda);
  const p = {
    prof: c.profundidad_mm,
    etiqueta: c.profundidad_mm + " mm",
    banda: modal.banda,
    fNat: modal.fNatural,
    aArm: { fs: aArm.fs, t: aArm.t, c: aArm.canales.map(tarar) },
    fArm: { fs: fArm.fs, t: fArm.t, c: fArm.canales.map(tarar) },
    a: aRes,
    f: fRes,
    pieza: PIEZA[String(c.profundidad_mm)]
  };
  const ra = p.pieza.ra;
  p.raMedia = ra.reduce((s, v) => s + v, 0) / ra.length;
  p.raDesv = Math.sqrt(ra.reduce((s, v) => s + (v - p.raMedia) ** 2, 0) / (ra.length - 1));
  console.log(`${p.etiqueta}: fn=${p.fNat.toFixed(1)} Hz, RMS acel=${aRes.rmsR.toFixed(4)} g, RMS fuerza=${fRes.rmsR.toFixed(4)} V, Ra=${p.raMedia.toFixed(2)} µm, chatter=${aRes.chatter}`);
  return p;
});
const N = pruebas.length;

/* ---------- utilidades de dibujo ---------- */
function nuevoLienzo(w, h, titulo, subtitulo) {
  const cv = createCanvas(w, h);
  const g = cv.getContext("2d");
  g.fillStyle = "#ffffff";
  g.fillRect(0, 0, w, h);
  g.fillStyle = "#14213d";
  g.font = `bold 30px ${FUENTE}`;
  g.textAlign = "left";
  g.textBaseline = "alphabetic";
  g.fillText(titulo, 40, 48);
  if (subtitulo) {
    g.fillStyle = "#5c677d";
    g.font = `18px ${FUENTE}`;
    g.fillText(subtitulo, 40, 76);
  }
  return { cv, g, w, h };
}

function guardar(lienzo, nombre) {
  fs.writeFileSync(path.join(SALIDA, nombre), lienzo.cv.toBuffer("image/png"));
  console.log("  ->", nombre);
}

function bonito(min, max, n) {
  if (!(max > min)) { max = min + 1; }
  const paso0 = (max - min) / n;
  const mag = Math.pow(10, Math.floor(Math.log10(paso0)));
  const r = paso0 / mag;
  const paso = (r < 1.5 ? 1 : r < 3 ? 2 : r < 7 ? 5 : 10) * mag;
  const ini = Math.ceil(min / paso - 1e-9) * paso;
  const t = [];
  for (let v = ini; v <= max + paso * 1e-6; v += paso) t.push(Math.abs(v) < paso * 1e-9 ? 0 : v);
  return { ticks: t, paso };
}

function fmtTick(v, paso) {
  const dec = Math.max(0, -Math.floor(Math.log10(paso) + 1e-9));
  return v.toFixed(Math.min(dec, 4));
}

/* Eje con rejilla. box = {x,y,w,h}. opts: xlim, ylim, titulo, xlab, ylab, nx, ny */
function ejes(g, box, o) {
  const { x, y, w, h } = box;
  g.save();
  g.fillStyle = "#fbfcfe";
  g.fillRect(x, y, w, h);
  const tx = bonito(o.xlim[0], o.xlim[1], o.nx || 5);
  const ty = bonito(o.ylim[0], o.ylim[1], o.ny || 4);
  g.font = `14px ${FUENTE}`;
  g.lineWidth = 1;
  g.strokeStyle = "#e3e8ef";
  g.fillStyle = "#5c677d";
  g.textAlign = "center";
  g.textBaseline = "top";
  tx.ticks.forEach((v) => {
    const px = x + ((v - o.xlim[0]) / (o.xlim[1] - o.xlim[0])) * w;
    g.beginPath(); g.moveTo(px, y); g.lineTo(px, y + h); g.stroke();
    g.fillText(fmtTick(v, tx.paso), px, y + h + 5);
  });
  g.textAlign = "right";
  g.textBaseline = "middle";
  ty.ticks.forEach((v) => {
    const py = y + h - ((v - o.ylim[0]) / (o.ylim[1] - o.ylim[0])) * h;
    g.beginPath(); g.moveTo(x, py); g.lineTo(x + w, py); g.stroke();
    g.fillText(fmtTick(v, ty.paso), x - 6, py);
  });
  g.strokeStyle = "#8d99ae";
  g.strokeRect(x, y, w, h);
  if (o.titulo) {
    g.fillStyle = "#14213d";
    g.font = `bold 17px ${FUENTE}`;
    g.textAlign = "left";
    g.textBaseline = "alphabetic";
    g.fillText(o.titulo, x, y - 10);
  }
  g.fillStyle = "#3d4a63";
  g.font = `15px ${FUENTE}`;
  if (o.xlab) { g.textAlign = "center"; g.textBaseline = "alphabetic"; g.fillText(o.xlab, x + w / 2, y + h + 38); }
  if (o.ylab) {
    g.save();
    g.translate(x - 56, y + h / 2);
    g.rotate(-Math.PI / 2);
    g.textAlign = "center";
    g.textBaseline = "alphabetic";
    g.fillText(o.ylab, 0, 0);
    g.restore();
  }
  g.restore();
  const mx = (v) => x + ((v - o.xlim[0]) / (o.xlim[1] - o.xlim[0])) * w;
  const my = (v) => y + h - ((v - o.ylim[0]) / (o.ylim[1] - o.ylim[0])) * h;
  return { mx, my, box, o };
}

function linea(g, E, xs, ys, color, lw, i0, i1) {
  const { box, o } = E;
  g.save();
  g.beginPath();
  g.rect(box.x, box.y, box.w, box.h);
  g.clip();
  g.strokeStyle = color;
  g.lineWidth = lw || 1;
  g.lineJoin = "round";
  g.beginPath();
  let pen = false;
  const a = i0 || 0, b = i1 === undefined ? xs.length : i1;
  for (let i = a; i < b; i++) {
    if (!Number.isFinite(ys[i])) { pen = false; continue; }
    const px = E.mx(xs[i]), py = E.my(ys[i]);
    if (!pen) { g.moveTo(px, py); pen = true; } else g.lineTo(px, py);
  }
  g.stroke();
  g.restore();
}

function banda(g, E, f0, f1, color) {
  g.save();
  g.fillStyle = color || "rgba(214,40,57,0.13)";
  const x0 = Math.max(E.mx(f0), E.box.x), x1 = Math.min(E.mx(f1), E.box.x + E.box.w);
  g.fillRect(x0, E.box.y, x1 - x0, E.box.h);
  g.restore();
}

function vertical(g, E, xv, color, texto, dash) {
  g.save();
  g.strokeStyle = color;
  g.lineWidth = 1.4;
  g.setLineDash(dash || [6, 4]);
  g.beginPath();
  g.moveTo(E.mx(xv), E.box.y);
  g.lineTo(E.mx(xv), E.box.y + E.box.h);
  g.stroke();
  g.setLineDash([]);
  if (texto) {
    g.fillStyle = color;
    g.font = `13px ${FUENTE}`;
    g.textAlign = "left";
    g.textBaseline = "top";
    g.fillText(texto, E.mx(xv) + 4, E.box.y + 4);
  }
  g.restore();
}

function leyenda(g, x, y, items, ancho) {
  g.save();
  g.font = `15px ${FUENTE}`;
  g.textBaseline = "middle";
  g.textAlign = "left";
  let px = x;
  items.forEach(([txt, col]) => {
    g.fillStyle = col;
    g.fillRect(px, y - 6, 22, 12);
    g.fillStyle = "#14213d";
    g.fillText(txt, px + 28, y);
    px += 28 + g.measureText(txt).width + (ancho || 26);
  });
  g.restore();
}

function rango(arr, margen) {
  let mn = Infinity, mx = -Infinity;
  for (let i = 0; i < arr.length; i++) {
    const v = arr[i];
    if (Number.isFinite(v)) { if (v < mn) mn = v; if (v > mx) mx = v; }
  }
  const d = (mx - mn) * (margen === undefined ? 0.08 : margen) || 1;
  return [mn - d, mx + d];
}

function maxAbs(lista) {
  let m = 0;
  lista.forEach((a) => { for (let i = 0; i < a.length; i++) { const v = Math.abs(a[i]); if (Number.isFinite(v) && v > m) m = v; } });
  return m;
}

function ordenSuperior(v) { return v; }

/* ---------- Figura 1 y 2: señales temporales (X, Y, Z x profundidad) ---------- */
function figuraTiempo(clave, nombreArchivo, titulo, unidad, ylabBase) {
  const W = 2000, H = 1130;
  const L = nuevoLienzo(W, H, titulo, `Tiempo continuo de la grabación completa · ${RPM} rpm · una columna por profundidad de corte · misma escala vertical por fila`);
  const g = L.g;
  const mIzq = 100, mDer = 30, top0 = 130, alto = 250, sepV = 62;
  const sepH = 45;
  const ancho = (W - mIzq - mDer - sepH * (N - 1)) / N;
  for (let e = 0; e < 3; e++) {
    const lim = maxAbs(pruebas.map((p) => p[clave].y[e])) * 1.08;
    for (let k = 0; k < N; k++) {
      const p = pruebas[k];
      const r = p[clave];
      const tmax = r.t[r.t.length - 1];
      const box = { x: mIzq + k * (ancho + sepH), y: top0 + e * (alto + sepV), w: ancho, h: alto };
      const E = ejes(g, box, {
        xlim: [0, tmax], ylim: [-lim, lim], nx: 5, ny: 4,
        titulo: (e === 0 ? p.etiqueta + " de profundidad · " : "") + `${ylabBase} ${EJES[e]}`,
        xlab: e === 2 ? "Tiempo [s]" : "", ylab: k === 0 ? `${EJES[e]} [${unidad}]` : ""
      });
      linea(g, E, r.t, r.y[e], COL_PROF[k], 0.8);
      const rms = r.rms[e];
      g.fillStyle = "#14213d";
      g.font = `bold 14px ${FUENTE}`;
      g.textAlign = "right";
      g.textBaseline = "top";
      g.fillText(`RMS = ${rms.toFixed(clave === "a" ? 3 : 3)} ${unidad}`, box.x + box.w - 8, box.y + 6);
    }
  }
  guardar(L, nombreArchivo);
}

/* ---------- Figura 3: zoom de la señal ---------- */
function figuraZoom() {
  const W = 2000, H = 900;
  const L = nuevoLienzo(W, H, "Detalle de la señal temporal (ventana corta, mitad del corte)",
    `Aceleración: 0.1 s · Fuerza: 0.5 s (≈ 6 vueltas del husillo a ${RPM} rpm = ${F_HUSILLO} Hz)`);
  const g = L.g;
  const mIzq = 100, mDer = 30, top0 = 130, alto = 280, sepV = 70, sepH = 45;
  const ancho = (W - mIzq - mDer - sepH * (N - 1)) / N;
  const filas = [
    { clave: "aArm", dur: 0.1, unidad: "g", nom: "Aceleración", fmtT: 1000, xlab: "Tiempo [ms]" },
    { clave: "fArm", dur: 0.5, unidad: "V", nom: "Fuerza", fmtT: 1, xlab: "Tiempo [s]" }
  ];
  filas.forEach((fila, r) => {
    const lim = maxAbs(pruebas.map((p) => {
      const a = p[fila.clave];
      const ini = Math.floor(a.c[0].length / 2);
      const n = Math.round(fila.dur * a.fs);
      return Float64Array.from([].concat(...a.c.map((c) => Array.from(c.subarray(ini, ini + n)))));
    })) * 1.08;
    for (let k = 0; k < N; k++) {
      const p = pruebas[k];
      const a = p[fila.clave];
      const ini = Math.floor(a.c[0].length / 2);
      const n = Math.round(fila.dur * a.fs);
      const tt = new Float64Array(n);
      for (let i = 0; i < n; i++) tt[i] = (i / a.fs) * fila.fmtT;
      const box = { x: mIzq + k * (ancho + sepH), y: 130 + r * (alto + sepV), w: ancho, h: alto };
      const E = ejes(g, box, {
        xlim: [0, fila.dur * fila.fmtT], ylim: [-lim, lim], nx: 5, ny: 4,
        titulo: `${fila.nom} · ${p.etiqueta}`, xlab: fila.xlab, ylab: k === 0 ? `[${fila.unidad}]` : ""
      });
      for (let e = 0; e < 3; e++) linea(g, E, tt, a.c[e].subarray(ini, ini + n), COL_EJE[e], 1.1);
    }
  });
  leyenda(g, 100, H - 30, [["Eje X", COL_EJE[0]], ["Eje Y", COL_EJE[1]], ["Eje Z", COL_EJE[2]]]);
  guardar(L, "3_detalle_senal_temporal.png");
}

/* ---------- Figura 4: RMS ---------- */
function barrasAgrupadas(g, box, o) {
  // o: cats[], series[{nombre,color,valores[]}], titulo, ylab, dec, errores?[][]
  const maxV = Math.max(...o.series.flatMap((s, si) => s.valores.map((v, i) => v + (s.err ? s.err[i] : 0)))) * 1.18;
  const E = ejes(g, box, { xlim: [0, o.cats.length], ylim: [0, maxV], nx: 1, ny: 5, titulo: o.titulo, ylab: o.ylab, xlab: o.xlab });
  // etiquetas de categoría (sustituye ticks numéricos del eje X)
  g.save();
  g.fillStyle = "#ffffff";
  g.fillRect(box.x - 2, box.y + box.h + 2, box.w + 4, 22);
  g.fillStyle = "#3d4a63";
  g.font = `15px ${FUENTE}`;
  g.textAlign = "center";
  g.textBaseline = "top";
  o.cats.forEach((c, i) => g.fillText(c, E.mx(i + 0.5), box.y + box.h + 6));
  g.restore();
  const ns = o.series.length;
  const ancho = 0.78 / ns;
  o.series.forEach((s, si) => {
    s.valores.forEach((v, i) => {
      const x0 = i + 0.11 + si * ancho;
      g.fillStyle = s.color;
      const px = E.mx(x0), py = E.my(v);
      g.fillRect(px, py, E.mx(x0 + ancho * 0.92) - px, E.my(0) - py);
      if (s.err) {
        const cx = (px + E.mx(x0 + ancho * 0.92)) / 2;
        g.strokeStyle = "#14213d";
        g.lineWidth = 1.6;
        g.beginPath();
        g.moveTo(cx, E.my(v - s.err[i])); g.lineTo(cx, E.my(v + s.err[i]));
        g.moveTo(cx - 5, E.my(v + s.err[i])); g.lineTo(cx + 5, E.my(v + s.err[i]));
        g.moveTo(cx - 5, E.my(v - s.err[i])); g.lineTo(cx + 5, E.my(v - s.err[i]));
        g.stroke();
      }
      if (o.etiquetas !== false) {
        g.fillStyle = "#14213d";
        g.font = `12px ${FUENTE}`;
        g.textAlign = "center";
        g.textBaseline = "bottom";
        g.fillText(v.toFixed(o.dec), (px + E.mx(x0 + ancho * 0.92)) / 2, E.my(v + (s.err ? s.err[i] : 0)) - 3);
      }
    });
  });
  return E;
}

function figuraRMS() {
  const W = 2000, H = 1100;
  const L = nuevoLienzo(W, H, "Valor RMS de aceleración y de fuerza", "Arriba: RMS global por eje para cada profundidad · Abajo: evolución del RMS en el tiempo (60 ventanas, magnitud X-Y-Z)");
  const g = L.g;
  const cats = pruebas.map((p) => p.etiqueta);
  barrasAgrupadas(g, { x: 110, y: 130, w: 810, h: 340 }, {
    cats, titulo: "RMS de aceleración por eje", ylab: "RMS [g]", dec: 3, xlab: "Profundidad de corte",
    series: EJES.map((e, i) => ({ nombre: e, color: COL_EJE[i], valores: pruebas.map((p) => p.a.rms[i]) }))
  });
  barrasAgrupadas(g, { x: 1090, y: 130, w: 810, h: 340 }, {
    cats, titulo: "RMS de fuerza por eje (señal en volts, sin calibrar)", ylab: "RMS [V]", dec: 3, xlab: "Profundidad de corte",
    series: EJES.map((e, i) => ({ nombre: "F" + e, color: COL_EJE[i], valores: pruebas.map((p) => p.f.rms[i]) }))
  });
  leyenda(g, 110, 98, EJES.map((e, i) => ["Eje " + e, COL_EJE[i]]));

  const evolucion = (box, clave, titulo, ylab) => {
    const lim = Math.max(...pruebas.map((p) => Math.max(...p[clave].evol.r))) * 1.12;
    const tmax = Math.max(...pruebas.map((p) => p[clave].evol.t[p[clave].evol.t.length - 1]));
    const E = ejes(g, box, { xlim: [0, tmax], ylim: [0, lim], titulo, xlab: "Tiempo [s]", ylab });
    pruebas.forEach((p, k) => linea(g, E, p[clave].evol.t, p[clave].evol.r, COL_PROF[k], 2.2));
  };
  evolucion({ x: 110, y: 640, w: 810, h: 340 }, "a", "Evolución del RMS de aceleración", "RMS [g]");
  evolucion({ x: 1090, y: 640, w: 810, h: 340 }, "f", "Evolución del RMS de fuerza", "RMS [V]");
  leyenda(g, 110, 605, pruebas.map((p, k) => [p.etiqueta, COL_PROF[k]]));
  leyenda(g, 1090, 605, pruebas.map((p, k) => [p.etiqueta, COL_PROF[k]]));
  guardar(L, "4_RMS_aceleracion_y_fuerza.png");
}

/* ---------- Figura 5 y 6: FFT ---------- */
function figuraFFT(clave, nombreArchivo, titulo, unidad, base, fmax, marcas) {
  const W = 2000, H = 1130;
  const L = nuevoLienzo(W, H, titulo,
    `FFT de un solo lado con ventana Hann · una columna por profundidad · misma escala vertical por fila` + (clave === "a" ? " · zona roja = banda modal analizada" : ` · línea punteada = frecuencia del husillo (${F_HUSILLO} Hz)`));
  const g = L.g;
  const mIzq = 100, mDer = 30, top0 = 130, alto = 250, sepV = 62, sepH = 45;
  const ancho = (W - mIzq - mDer - sepH * (N - 1)) / N;
  for (let e = 0; e < 3; e++) {
    let lim = 0;
    pruebas.forEach((p) => {
      const r = p[clave];
      for (let i = 0; i < r.f.length; i++) if (r.f[i] >= 2 && r.f[i] <= fmax && r.p[e][i] > lim) lim = r.p[e][i];
    });
    lim *= 1.12;
    for (let k = 0; k < N; k++) {
      const p = pruebas[k];
      const r = p[clave];
      const box = { x: mIzq + k * (ancho + sepH), y: top0 + e * (alto + sepV), w: ancho, h: alto };
      const E = ejes(g, box, {
        xlim: [0, fmax], ylim: [0, lim], nx: 5, ny: 4,
        titulo: (e === 0 ? p.etiqueta + " · " : "") + `${base} ${EJES[e]}`,
        xlab: e === 2 ? "Frecuencia [Hz]" : "", ylab: k === 0 ? `Amplitud ${EJES[e]} [${unidad}]` : ""
      });
      if (clave === "a") banda(g, E, p.banda[0], p.banda[1]);
      else for (let h = 1; h * F_HUSILLO <= fmax && h <= 1; h++) vertical(g, E, h * F_HUSILLO, "#7b2cbf", null);
      // desde 2 Hz para ocultar la deriva de continua
      let i0 = 0;
      while (i0 < r.f.length && r.f[i0] < 2) i0++;
      linea(g, E, r.f, r.p[e], COL_PROF[k], 1.1, i0);
      // pico principal
      let ip = -1, mx = -Infinity;
      for (let i = i0; i < r.f.length; i++) if (r.f[i] <= fmax && r.p[e][i] > mx) { mx = r.p[e][i]; ip = i; }
      if (ip >= 0) {
        g.save();
        g.fillStyle = "#14213d";
        g.beginPath(); g.arc(E.mx(r.f[ip]), E.my(mx), 4, 0, Math.PI * 2); g.fill();
        g.font = `bold 13px ${FUENTE}`;
        g.textBaseline = "top";
        const px = E.mx(r.f[ip]);
        g.textAlign = px > box.x + box.w * 0.7 ? "right" : "left";
        g.fillText(`${r.f[ip].toFixed(0)} Hz · ${mx.toFixed(4)} ${unidad}`, px + (g.textAlign === "left" ? 8 : -8), box.y + 8);
        g.restore();
      }
    }
  }
  guardar(L, nombreArchivo);
}

/* ---------- Figura 7: rugosidad ---------- */
function regresion(x, y) {
  const n = x.length;
  const mx = x.reduce((s, v) => s + v, 0) / n, my = y.reduce((s, v) => s + v, 0) / n;
  let sxy = 0, sxx = 0, syy = 0;
  for (let i = 0; i < n; i++) { sxy += (x[i] - mx) * (y[i] - my); sxx += (x[i] - mx) ** 2; syy += (y[i] - my) ** 2; }
  const b = sxy / sxx, a = my - b * mx;
  return { a, b, r2: (sxy * sxy) / (sxx * syy) };
}

function dispersion(g, box, o) {
  const [x0, x1] = rango(o.x, 0.15), [y0, y1] = rango(o.y.concat([0]), 0.12);
  const E = ejes(g, box, { xlim: [Math.max(0, x0), x1], ylim: [0, y1], titulo: o.titulo, xlab: o.xlab, ylab: o.ylab, nx: 5, ny: 5 });
  const rg = regresion(o.x, o.y);
  const xa = Math.max(0, x0), xb = x1;
  g.save();
  g.strokeStyle = "#8d99ae";
  g.setLineDash([8, 5]);
  g.lineWidth = 1.8;
  g.beginPath(); g.moveTo(E.mx(xa), E.my(rg.a + rg.b * xa)); g.lineTo(E.mx(xb), E.my(rg.a + rg.b * xb)); g.stroke();
  g.restore();
  o.x.forEach((v, i) => {
    g.fillStyle = COL_PROF[i];
    g.strokeStyle = "#14213d";
    g.lineWidth = 1.5;
    g.beginPath(); g.arc(E.mx(v), E.my(o.y[i]), 9, 0, Math.PI * 2); g.fill(); g.stroke();
    g.fillStyle = "#14213d";
    g.font = `bold 13px ${FUENTE}`;
    g.textAlign = "left";
    g.textBaseline = "middle";
    g.fillText(pruebas[i].etiqueta, E.mx(v) + 13, E.my(o.y[i]) + 2);
  });
  g.fillStyle = "#14213d";
  g.font = `bold 15px ${FUENTE}`;
  g.textAlign = "right";
  g.textBaseline = "top";
  g.fillText(`R² = ${rg.r2.toFixed(3)}`, box.x + box.w - 10, box.y + 8);
  return rg;
}

function figuraRugosidad() {
  const W = 2000, H = 1130;
  const L = nuevoLienzo(W, H, "Rugosidad superficial y su relación con la vibración y la fuerza",
    "Rugosidad medida con cinco lecturas por profundidad · las barras de error son ± 1 desviación estándar");
  const g = L.g;
  const cats = pruebas.map((p) => p.etiqueta);
  const Eb = barrasAgrupadas(g, { x: 110, y: 130, w: 810, h: 340 }, {
    cats, titulo: "Rugosidad media Ra", ylab: "Ra [µm]", dec: 2, xlab: "Profundidad de corte",
    series: [{ nombre: "Ra", color: "#5a6ee0", valores: pruebas.map((p) => p.raMedia), err: pruebas.map((p) => p.raDesv) }]
  });
  // lecturas individuales
  const E2 = ejes(g, { x: 1090, y: 130, w: 810, h: 340 }, { xlim: [0, N], ylim: [0, 7.5], nx: 1, ny: 5, titulo: "Rugosidad por lectura (5 lecturas)", ylab: "Ra [µm]", xlab: "Profundidad de corte" });
  g.fillStyle = "#ffffff"; g.fillRect(1088, 474, 814, 22);
  g.fillStyle = "#3d4a63"; g.font = `15px ${FUENTE}`; g.textAlign = "center"; g.textBaseline = "top";
  pruebas.forEach((p, k) => g.fillText(p.etiqueta, E2.mx(k + 0.5), 130 + 340 + 6));
  const marcas = ["#2a9d8f", "#e9c46a", "#f4802a", "#d62839", "#7b2cbf"];
  pruebas.forEach((p, k) => {
    p.pieza.ra.forEach((v, j) => {
      const cx = E2.mx(k + 0.2 + j * 0.15);
      g.fillStyle = marcas[j]; g.strokeStyle = "#14213d"; g.lineWidth = 1;
      g.beginPath(); g.arc(cx, E2.my(v), 6.5, 0, Math.PI * 2); g.fill(); g.stroke();
    });
    g.strokeStyle = "#14213d"; g.lineWidth = 2; g.setLineDash([5, 4]);
    g.beginPath(); g.moveTo(E2.mx(k + 0.12), E2.my(p.raMedia)); g.lineTo(E2.mx(k + 0.88), E2.my(p.raMedia)); g.stroke(); g.setLineDash([]);
  });
  leyenda(g, 1090, 98, marcas.map((c, j) => [`Lectura ${j + 1}`, c]), 14);

  const rgA = dispersion(g, { x: 110, y: 640, w: 810, h: 340 }, {
    x: pruebas.map((p) => p.a.rmsR), y: pruebas.map((p) => p.raMedia),
    titulo: "Ra vs. RMS de aceleración", xlab: "RMS de aceleración [g]", ylab: "Ra [µm]"
  });
  const rgF = dispersion(g, { x: 1090, y: 640, w: 810, h: 340 }, {
    x: pruebas.map((p) => p.f.rmsR), y: pruebas.map((p) => p.raMedia),
    titulo: "Ra vs. RMS de fuerza", xlab: "RMS de fuerza [V]", ylab: "Ra [µm]"
  });
  guardar(L, "7_rugosidad.png");
  return { rgA, rgF };
}

/* ---------- Figura 8: resumen conjunto ---------- */
function figuraResumen() {
  const W = 2000, H = 760;
  const L = nuevoLienzo(W, H, "Resumen: fuerza, vibración y rugosidad frente a la profundidad de corte",
    "Cada curva se compara contra la rugosidad media Ra (eje derecho, rojo)");
  const g = L.g;
  const profs = pruebas.map((p) => p.prof);
  const paneles = [
    { titulo: "Vibración (RMS de aceleración) y Ra", clave: (p) => p.a.rmsR, ylab: "RMS aceleración [g]", col: "#1d6fd1" },
    { titulo: "Fuerza (RMS) y Ra", clave: (p) => p.f.rmsR, ylab: "RMS fuerza [V]", col: "#2a9d3f" },
    { titulo: "Amplitud del pico modal y Ra", clave: (p) => p.a.ampModal, ylab: "Pico en banda modal [g]", col: "#7b2cbf" }
  ];
  const ancho = 570, sep = 120, x0 = 110;
  paneles.forEach((pn, i) => {
    const box = { x: x0 + i * (ancho + sep), y: 150, w: ancho, h: 440 };
    const v = pruebas.map(pn.clave);
    const vmax = Math.max(...v) * 1.2;
    const raMax = Math.max(...pruebas.map((p) => p.raMedia + p.raDesv)) * 1.2;
    const E = ejes(g, box, { xlim: [0.75, 2.75], ylim: [0, vmax], nx: 4, ny: 5, titulo: pn.titulo, xlab: "Profundidad de corte [mm]", ylab: pn.ylab });
    // eje derecho
    g.save();
    g.font = `14px ${FUENTE}`;
    g.fillStyle = "#d62839";
    g.textAlign = "left";
    g.textBaseline = "middle";
    const t2 = bonito(0, raMax, 5);
    t2.ticks.forEach((tv) => g.fillText(fmtTick(tv, t2.paso), box.x + box.w + 8, box.y + box.h - (tv / raMax) * box.h));
    g.translate(box.x + box.w + 56, box.y + box.h / 2);
    g.rotate(Math.PI / 2);
    g.textAlign = "center";
    g.font = `15px ${FUENTE}`;
    g.fillText("Ra [µm]", 0, 0);
    g.restore();
    linea(g, E, profs, v, pn.col, 3);
    profs.forEach((pr, k) => {
      g.fillStyle = pn.col; g.beginPath(); g.arc(E.mx(pr), E.my(v[k]), 7, 0, Math.PI * 2); g.fill();
    });
    const my2 = (r) => box.y + box.h - (r / raMax) * box.h;
    g.save();
    g.strokeStyle = "#d62839"; g.lineWidth = 3; g.setLineDash([10, 5]);
    g.beginPath();
    pruebas.forEach((p, k) => { const px = E.mx(p.prof), py = my2(p.raMedia); if (k === 0) g.moveTo(px, py); else g.lineTo(px, py); });
    g.stroke(); g.setLineDash([]);
    pruebas.forEach((p) => {
      const px = E.mx(p.prof);
      g.strokeStyle = "#d62839"; g.lineWidth = 1.6;
      g.beginPath(); g.moveTo(px, my2(p.raMedia - p.raDesv)); g.lineTo(px, my2(p.raMedia + p.raDesv)); g.stroke();
      g.fillStyle = "#ffffff"; g.beginPath(); g.rect(px - 7, my2(p.raMedia) - 7, 14, 14); g.fill(); g.stroke();
    });
    g.restore();
    leyenda(g, box.x, box.y - 40, [[pn.ylab.split(" [")[0], pn.col], ["Ra (eje derecho)", "#d62839"]]);
  });
  guardar(L, "8_resumen_fuerza_vibracion_rugosidad.png");
}

/* ---------- Figura 9: tabla resumen ---------- */
function figuraTabla(rg) {
  const filas = pruebas.map((p) => [
    p.etiqueta,
    p.a.rms[0].toFixed(3), p.a.rms[1].toFixed(3), p.a.rms[2].toFixed(3), p.a.rmsR.toFixed(3),
    p.f.rms[0].toFixed(3), p.f.rms[1].toFixed(3), p.f.rms[2].toFixed(3), p.f.rmsR.toFixed(3),
    p.fNat.toFixed(0),
    Number.isFinite(p.a.fModal) ? p.a.fModal.toFixed(0) : "—",
    p.a.chatter ? "Sí (" + p.a.eje + ")" : "No",
    p.raMedia.toFixed(2) + " ± " + p.raDesv.toFixed(2)
  ]);
  const cab = ["Profundidad", "RMS ax [g]", "RMS ay [g]", "RMS az [g]", "RMS a total [g]", "RMS Fx [V]", "RMS Fy [V]", "RMS Fz [V]", "RMS F total [V]", "fn modal [Hz]", "Pico en banda [Hz]", "Chatter", "Ra [µm]"];
  const W = 2000, H = 150 + 70 * (filas.length + 1) + 60;
  const L = nuevoLienzo(W, H, "Tabla resumen de resultados", `fn = frecuencia natural del análisis modal · Fuerza en volts (sin calibrar) · ${RPM} rpm`);
  const g = L.g;
  const colW = (W - 80) / cab.length;
  g.textBaseline = "middle";
  g.textAlign = "center";
  [cab, ...filas].forEach((fila, r) => {
    const y = 110 + r * 70;
    g.fillStyle = r === 0 ? "#14213d" : (r % 2 ? "#f1f4fa" : "#ffffff");
    g.fillRect(40, y, W - 80, 70);
    fila.forEach((c, i) => {
      g.fillStyle = r === 0 ? "#ffffff" : "#14213d";
      g.font = `${r === 0 ? "bold 15" : (i === 0 ? "bold 19" : "19")}px ${FUENTE}`;
      g.fillText(c, 40 + colW * (i + 0.5), y + 35, colW - 10);
    });
  });
  guardar(L, "9_tabla_resumen.png");

  const csv = [cab.join(",")].concat(filas.map((f) => f.map((c) => `"${c}"`).join(","))).join("\n");
  fs.writeFileSync(path.join(SALIDA, "resumen.csv"), "\ufeff" + csv, "utf8");
}

/* ---------- ejecución ---------- */
console.log("Generando figuras...");
figuraTiempo("a", "1_aceleracion_tiempo.png", "Señales temporales de aceleración (vibración) por profundidad de corte", "g", "Aceleración");
figuraTiempo("f", "2_fuerza_tiempo.png", "Señales temporales de fuerza por profundidad de corte (volts, sin calibrar)", "V", "Fuerza");
figuraZoom();
figuraRMS();
figuraFFT("a", "5_FFT_aceleracion.png", "Espectro FFT de aceleración (vibración)", "g", "FFT aceleración", 3000);
figuraFFT("f", "6_FFT_fuerza.png", "Espectro FFT de fuerza", "V", "FFT fuerza", 1500);
const rg = figuraRugosidad();
figuraResumen();
figuraTabla(rg);
console.log(`R² Ra~RMS aceleración = ${rg.rgA.r2.toFixed(3)} · R² Ra~RMS fuerza = ${rg.rgF.r2.toFixed(3)}`);
