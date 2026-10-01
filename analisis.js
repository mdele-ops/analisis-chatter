(function (root) {
  "use strict";

  function sinAcento(s) {
    return String(s)
      .replace(/á/gi, "a")
      .replace(/é/gi, "e")
      .replace(/í/gi, "i")
      .replace(/ó/gi, "o")
      .replace(/ú/gi, "u")
      .replace(/ñ/gi, "n");
  }

  function median(vals) {
    const v = vals.filter(function (x) { return Number.isFinite(x); }).sort(function (a, b) { return a - b; });
    if (!v.length) return NaN;
    const m = Math.floor(v.length / 2);
    return v.length % 2 ? v[m] : (v[m - 1] + v[m]) / 2;
  }

  function tipoCarpeta(nombre) {
    const s = sinAcento(nombre).toLowerCase().trim();
    if (s === "x" || s === "y" || s === "z") return "";
    if (s.indexOf("aceler") >= 0 || s.indexOf("accel") >= 0) return "aceleracion";
    if (s.indexOf("fuerza") >= 0 || s.indexOf("force") >= 0) return "fuerza";
    if (s.indexOf("modal") >= 0 || s.indexOf("impacto") >= 0) return "modal";
    return "";
  }

  function ejeDeRuta(ruta) {
    const partes = String(ruta).split(/[/\\]/);
    for (let i = partes.length - 1; i >= 0; i--) {
      if (/^[xyz]$/i.test(partes[i])) return partes[i].toUpperCase();
    }
    const base = partes[partes.length - 1] || "";
    const m = base.match(/(^|[_\-\s])([xyz])([_\-\s.]|$)/i);
    return m ? m[2].toUpperCase() : "";
  }

  function ordenArchivo(nombre) {
    const base = String(nombre).split(/[/\\]/).pop();
    const pref = base.match(/[AFaf]_*(\d+)/);
    if (pref) return parseInt(pref[1], 10);
    const n = base.match(/(\d+)/);
    return n ? parseInt(n[1], 10) : 0;
  }

  function parseLVM(texto, nombre) {
    const lineas = String(texto).split(/\r?\n/);
    let deltaX = [];
    let nCanales = 0;
    let nombres = [];
    let inicio = -1;
    for (let i = 0; i < lineas.length; i++) {
      const t = lineas[i].trim();
      if (/^Delta_X/i.test(t)) {
        deltaX = numerosTrasTab(lineas[i]);
      } else if (/^Channels/i.test(t)) {
        const vals = numerosTrasTab(lineas[i]);
        if (vals.length) nCanales = vals[0];
      } else if (/^X_Value/i.test(t)) {
        nombres = nombresCanales(lineas[i]);
        inicio = i + 1;
        break;
      }
    }
    if (inicio < 0) {
      throw new Error("No se encontró X_Value en " + nombre);
    }
    if (!nCanales) {
      for (let i = inicio; i < lineas.length; i++) {
        const partes = lineas[i].split("\t");
        if (partes.length >= 2 && Number.isFinite(parseFloat(partes[0]))) {
          nCanales = 0;
          for (let c = 1; c < partes.length; c++) {
            if (Number.isFinite(parseFloat(partes[c]))) nCanales++;
            else break;
          }
          break;
        }
      }
    }
    if (!nCanales) {
      throw new Error("No hay columnas de datos en " + nombre);
    }
    const buckets = [];
    for (let c = 0; c < nCanales; c++) buckets.push([]);
    const tiempos = [];
    for (let i = inicio; i < lineas.length; i++) {
      if (!lineas[i]) continue;
      const partes = lineas[i].split("\t");
      if (partes.length < 2) continue;
      const t0 = parseFloat(partes[0]);
      if (!Number.isFinite(t0)) continue;
      tiempos.push(t0);
      for (let c = 0; c < nCanales; c++) {
        const v = parseFloat(partes[c + 1]);
        buckets[c].push(Number.isFinite(v) ? v : NaN);
      }
    }
    if (!buckets[0].length) {
      throw new Error("No hay datos numéricos en " + nombre);
    }
    let delta = median(deltaX);
    if (!Number.isFinite(delta)) {
      const dts = [];
      for (let i = 1; i < Math.min(tiempos.length, 200); i++) {
        const d = tiempos[i] - tiempos[i - 1];
        if (d > 0 && d < 1) dts.push(d);
      }
      delta = median(dts);
    }
    if (!Number.isFinite(delta) || delta <= 0) {
      throw new Error("No se pudo obtener Delta_X en " + nombre);
    }
    if (!nombres.length) {
      nombres = ["X", "Y", "Z"].slice(0, nCanales);
      while (nombres.length < nCanales) nombres.push("Canal " + (nombres.length + 1));
    }
    return {
      fs: 1 / delta,
      nombres: nombres.slice(0, nCanales),
      tiempos: Float64Array.from(tiempos),
      canales: buckets.map(function (b) { return Float64Array.from(b); })
    };
  }

  function numerosTrasTab(linea) {
    const partes = linea.split("\t");
    const vals = [];
    for (let i = 1; i < partes.length; i++) {
      const v = parseFloat(String(partes[i]).trim());
      if (Number.isFinite(v)) vals.push(v);
    }
    return vals;
  }

  function nombresCanales(linea) {
    const partes = linea.split("\t");
    const nombres = [];
    for (let i = 1; i < partes.length; i++) {
      const nombre = String(partes[i]).trim();
      if (!nombre || /^comment$/i.test(nombre)) continue;
      nombres.push(nombre);
    }
    return nombres;
  }

  function mapearEjes(nombres, nCan, ejeUnico) {
    const idx = [-1, -1, -1];
    const usados = [];
    const letras = ["x", "y", "z"];
    for (let c = 0; c < nCan; c++) usados.push(false);
    for (let k = 0; k < 3; k++) {
      for (let c = 0; c < nombres.length && c < nCan; c++) {
        if (usados[c]) continue;
        const token = sinAcento(nombres[c]).toLowerCase();
        const re = new RegExp("(^|[^a-z])" + letras[k] + "([^a-z]|$)");
        if (re.test(token) || token.indexOf("f" + letras[k]) >= 0 || token.indexOf("acel" + letras[k]) >= 0) {
          idx[k] = c;
          usados[c] = true;
          break;
        }
      }
    }
    if (idx[0] < 0 && idx[1] < 0 && idx[2] < 0) {
      if (nCan === 1) {
        const k = ejeUnico === "Y" ? 1 : ejeUnico === "Z" ? 2 : 0;
        idx[k] = 0;
      } else {
        for (let k = 0; k < Math.min(3, nCan); k++) idx[k] = k;
      }
    }
    return idx;
  }

  function concatenar(bloques) {
    if (!bloques.length) return [];
    const nCan = bloques[0].length;
    const out = [];
    for (let c = 0; c < nCan; c++) {
      let n = 0;
      for (let i = 0; i < bloques.length; i++) n += bloques[i][c].length;
      const col = new Float64Array(n);
      let p = 0;
      for (let i = 0; i < bloques.length; i++) {
        col.set(bloques[i][c], p);
        p += bloques[i][c].length;
      }
      out.push(col);
    }
    return out;
  }

  function concatenarTiempos(lista, fs) {
    let total = 0;
    lista.forEach(function (d) { total += d.canales[0].length; });
    const out = new Float64Array(total);
    // Los archivos se unen uno tras otro con eje de tiempo continuo: se ignoran
    // los pequeños huecos (~0.2 s) que deja el equipo entre una grabación y otra.
    for (let i = 0; i < total; i++) out[i] = i / fs;
    return out;
  }

  function armarXYZ(archivos, ejeUnico) {
    const porEje = { X: [], Y: [], Z: [] };
    let hayEjes = false;
    archivos.forEach(function (a) {
      if (a.eje && a.datos.canales.length === 1) {
        porEje[a.eje].push(a);
        hayEjes = true;
      }
    });
    if (hayEjes && (porEje.X.length + porEje.Y.length + porEje.Z.length) === archivos.length) {
      const cols = [null, null, null];
      const letras = ["X", "Y", "Z"];
      let fs = NaN;
      let tiempos = null;
      letras.forEach(function (letra, k) {
        if (!porEje[letra].length) return;
        const f0 = porEje[letra][0].datos.fs;
        porEje[letra].forEach(function (a) {
          if (Math.abs(a.datos.fs - f0) > 1) {
            throw new Error("La frecuencia de muestreo de " + letra + " no coincide.");
          }
        });
        porEje[letra].sort(function (a, b) { return a.orden - b.orden; });
        cols[k] = concatenar(porEje[letra].map(function (a) { return a.datos.canales; }))[0];
        if (!tiempos) tiempos = concatenarTiempos(porEje[letra].map(function (a) { return a.datos; }), f0);
        fs = f0;
      });
      const n = Math.min.apply(null, cols.filter(Boolean).map(function (c) { return c.length; }));
      const canales = cols.map(function (c) {
        if (!c) return null;
        return c.length === n ? c : c.subarray(0, n);
      });
      return { fs: fs, t: tiempos.subarray(0, n), canales: canales, nota: "Ejes leídos desde X, Y y Z." };
    }
    const ordenados = archivos.slice().sort(function (a, b) { return a.orden - b.orden; });
    const nCan = ordenados[0].datos.canales.length;
    const fs0 = ordenados[0].datos.fs;
    ordenados.forEach(function (a) {
      if (a.datos.canales.length !== nCan) {
        throw new Error(a.nombre + " no tiene los mismos canales que los demás.");
      }
    });
    const unidos = concatenar(ordenados.map(function (a) { return a.datos.canales; }));
    const idx = mapearEjes(ordenados[0].datos.nombres, nCan, ejeUnico);
    const canales = [null, null, null];
    for (let k = 0; k < 3; k++) {
      if (idx[k] >= 0) canales[k] = unidos[idx[k]];
    }
    let nota = "Canales: " + ordenados[0].datos.nombres.join(", ") + ".";
    const usados = idx.filter(function (v) { return v >= 0; });
    if (usados.length === 1) {
      nota = "Un canal asignado a " + ["X", "Y", "Z"][idx.indexOf(usados[0])] + ".";
    }
    const tiempos = concatenarTiempos(ordenados.map(function (a) { return a.datos; }), fs0);
    return { fs: fs0, t: tiempos, canales: canales, nota: nota };
  }

  function tarar(col) {
    const nTar = Math.min(1000, Math.max(1, Math.floor(col.length * 0.1)));
    let s = 0;
    let k = 0;
    for (let i = 0; i < nTar; i++) {
      if (Number.isFinite(col[i])) {
        s += col[i];
        k++;
      }
    }
    const media = k ? s / k : 0;
    const out = new Float64Array(col.length);
    for (let i = 0; i < col.length; i++) {
      out[i] = Number.isFinite(col[i]) ? col[i] - media : NaN;
    }
    return out;
  }

  function rms(col) {
    if (!col) return NaN;
    let s = 0;
    let k = 0;
    for (let i = 0; i < col.length; i++) {
      if (Number.isFinite(col[i])) {
        s += col[i] * col[i];
        k++;
      }
    }
    return k ? Math.sqrt(s / k) : NaN;
  }

  function magnitud(canales) {
    const base = canales.filter(Boolean)[0];
    const n = base ? base.length : 0;
    const m = new Float64Array(n);
    canales.forEach(function (col) {
      if (!col) return;
      for (let i = 0; i < n; i++) {
        if (Number.isFinite(col[i])) m[i] += col[i] * col[i];
      }
    });
    for (let i = 0; i < n; i++) m[i] = Math.sqrt(m[i]);
    return m;
  }

  function evolucionRMS(canales, mag, tiempos, nVent) {
    const n = mag.length;
    const vent = Math.max(1, Math.min(nVent, Math.floor(n / 4)));
    const paso = Math.max(1, Math.floor(n / vent));
    const t = new Float64Array(vent);
    const r = new Float64Array(vent);
    const y = [null, null, null];
    for (let c = 0; c < 3; c++) if (canales[c]) y[c] = new Float64Array(vent);
    function rmsTramo(col, ini, fin) {
      let s = 0;
      let k = 0;
      for (let i = ini; i < fin; i++) {
        if (Number.isFinite(col[i])) {
          s += col[i] * col[i];
          k++;
        }
      }
      return k ? Math.sqrt(s / k) : NaN;
    }
    for (let v = 0; v < vent; v++) {
      const ini = v * paso;
      const fin = v === vent - 1 ? n : Math.min(n, ini + paso);
      const medio = Math.min(n - 1, Math.floor((ini + fin - 1) / 2));
      t[v] = tiempos[medio];
      r[v] = rmsTramo(mag, ini, fin);
      for (let c = 0; c < 3; c++) if (canales[c]) y[c][v] = rmsTramo(canales[c], ini, fin);
    }
    return { t: t, y: y, r: r };
  }

  function movmean(x, w) {
    const n = x.length;
    const out = new Float64Array(n);
    const half = Math.floor(w / 2);
    const pref = new Float64Array(n + 1);
    for (let i = 0; i < n; i++) pref[i + 1] = pref[i] + (Number.isFinite(x[i]) ? x[i] : 0);
    for (let i = 0; i < n; i++) {
      const a = Math.max(0, i - half);
      const b = Math.min(n - 1, i + half);
      out[i] = (pref[b + 1] - pref[a]) / (b - a + 1);
    }
    return out;
  }

  function fftSimple(x, fs) {
    const src = [];
    for (let i = 0; i < x.length; i++) src.push(Number.isFinite(x[i]) ? x[i] : 0);
    const n = src.length;
    if (n < 8 || !(fs > 0)) return { f: new Float64Array(0), p: new Float64Array(0) };
    let media = 0;
    for (let i = 0; i < n; i++) media += src[i];
    media /= n;
    const re = new Float64Array(n);
    const im = new Float64Array(n);
    const den = Math.max(n - 1, 1);
    for (let i = 0; i < n; i++) {
      const ventana = 0.5 * (1 - Math.cos(2 * Math.PI * i / den));
      re[i] = (src[i] - media) * ventana;
    }
    fftArbitraria(re, im);
    const mitad = Math.floor(n / 2) + 1;
    const f = new Float64Array(mitad);
    const p = new Float64Array(mitad);
    for (let k = 0; k < mitad; k++) {
      f[k] = fs * k / n;
      let a = Math.hypot(re[k], im[k]) / n;
      if (k > 0 && k < mitad - 1) a *= 2;
      p[k] = a;
    }
    return { f: f, p: p };
  }

  function fftArbitraria(re, im) {
    const n = re.length;
    if ((n & (n - 1)) === 0) {
      fftRadix2(re, im);
      return;
    }
    let m = 1;
    while (m < 2 * n - 1) m <<= 1;
    const ar = new Float64Array(m);
    const ai = new Float64Array(m);
    const br = new Float64Array(m);
    const bi = new Float64Array(m);
    for (let i = 0; i < n; i++) {
      const ang = Math.PI * (i * i % (2 * n)) / n;
      const cos = Math.cos(ang);
      const sin = Math.sin(ang);
      ar[i] = re[i] * cos + im[i] * sin;
      ai[i] = im[i] * cos - re[i] * sin;
      br[i] = cos;
      bi[i] = sin;
      if (i > 0) {
        br[m - i] = cos;
        bi[m - i] = sin;
      }
    }
    fftRadix2(ar, ai);
    fftRadix2(br, bi);
    for (let i = 0; i < m; i++) {
      const real = ar[i] * br[i] - ai[i] * bi[i];
      ai[i] = ar[i] * bi[i] + ai[i] * br[i];
      ar[i] = real;
    }
    for (let i = 0; i < m; i++) ai[i] = -ai[i];
    fftRadix2(ar, ai);
    for (let i = 0; i < m; i++) {
      ar[i] /= m;
      ai[i] = -ai[i] / m;
    }
    for (let k = 0; k < n; k++) {
      const ang = Math.PI * (k * k % (2 * n)) / n;
      const cos = Math.cos(ang);
      const sin = Math.sin(ang);
      re[k] = ar[k] * cos + ai[k] * sin;
      im[k] = ai[k] * cos - ar[k] * sin;
    }
  }

  function fftRadix2(re, im) {
    const n = re.length;
    for (let i = 1, j = 0; i < n; i++) {
      let bit = n >> 1;
      for (; j & bit; bit >>= 1) j ^= bit;
      j ^= bit;
      if (i < j) {
        const tr = re[i];
        re[i] = re[j];
        re[j] = tr;
        const ti = im[i];
        im[i] = im[j];
        im[j] = ti;
      }
    }
    for (let len = 2; len <= n; len <<= 1) {
      const ang = -2 * Math.PI / len;
      const wlenRe = Math.cos(ang);
      const wlenIm = Math.sin(ang);
      for (let i = 0; i < n; i += len) {
        let wRe = 1;
        let wIm = 0;
        const medio = len >> 1;
        for (let k = 0; k < medio; k++) {
          const j = i + k + medio;
          const vRe = re[j] * wRe - im[j] * wIm;
          const vIm = re[j] * wIm + im[j] * wRe;
          re[j] = re[i + k] - vRe;
          im[j] = im[i + k] - vIm;
          re[i + k] += vRe;
          im[i + k] += vIm;
          const nwRe = wRe * wlenRe - wIm * wlenIm;
          wIm = wRe * wlenIm + wIm * wlenRe;
          wRe = nwRe;
        }
      }
    }
  }

  function tramosContinuos(t, fs) {
    const n = t.length;
    const tramos = [];
    let ini = 0;
    const umbral = 5 / fs;
    for (let i = 1; i < n; i++) {
      if (t[i] - t[i - 1] > umbral) {
        tramos.push([ini, i]);
        ini = i;
      }
    }
    if (n) tramos.push([ini, n]);
    return tramos;
  }

  function reducirTiempo(canales, tiempos, fs, maxPuntos) {
    const base = canales.filter(Boolean)[0];
    if (!base) return { t: new Float64Array(0), y: [] };
    const n = base.length;
    let t = tiempos;
    if (!t || t.length !== n) {
      t = new Float64Array(n);
      for (let i = 0; i < n; i++) t[i] = i / fs;
    }
    const tramos = tramosContinuos(t, fs);
    const bucket = Math.max(1, Math.ceil(n / Math.floor(maxPuntos / 2)));
    const tOut = [];
    const ys = [[], [], []];
    tramos.forEach(function (tramo, k) {
      for (let b = tramo[0]; b < tramo[1]; b += bucket) {
        const fin = Math.min(tramo[1], b + bucket);
        if (fin - b === 1) {
          tOut.push(t[b]);
          for (let c = 0; c < 3; c++) ys[c].push(canales[c] ? canales[c][b] : NaN);
          continue;
        }
        tOut.push(t[b], t[fin - 1]);
        for (let c = 0; c < 3; c++) {
          const col = canales[c];
          if (!col) {
            ys[c].push(NaN, NaN);
            continue;
          }
          let iMin = -1;
          let iMax = -1;
          for (let i = b; i < fin; i++) {
            if (!Number.isFinite(col[i])) continue;
            if (iMin < 0 || col[i] < col[iMin]) iMin = i;
            if (iMax < 0 || col[i] > col[iMax]) iMax = i;
          }
          if (iMin < 0) ys[c].push(NaN, NaN);
          else if (iMin <= iMax) ys[c].push(col[iMin], col[iMax]);
          else ys[c].push(col[iMax], col[iMin]);
        }
      }
      if (k < tramos.length - 1) {
        tOut.push(t[tramo[1] - 1]);
        for (let c = 0; c < 3; c++) ys[c].push(NaN);
      }
    });
    return {
      t: Float64Array.from(tOut),
      y: ys.map(function (col, c) { return canales[c] ? Float64Array.from(col) : null; })
    };
  }

  function reducirEspectro(f, espectros) {
    let ultimo = f.length;
    for (let i = 0; i < f.length; i++) {
      if (f[i] > 4000) {
        ultimo = i;
        break;
      }
    }
    if (ultimo <= 2500) {
      return {
        f: f.subarray(0, ultimo),
        p: espectros.map(function (p) { return p ? p.subarray(0, ultimo) : null; })
      };
    }
    const bucket = Math.ceil(ultimo / 2500);
    const fs = [];
    const ps = espectros.map(function () { return []; });
    for (let b = 0; b < ultimo; b += bucket) {
      const fin = Math.min(ultimo, b + bucket);
      let iBest = b;
      let mejor = -Infinity;
      for (let i = b; i < fin; i++) {
        let pico = -Infinity;
        for (let c = 0; c < espectros.length; c++) {
          if (espectros[c] && espectros[c][i] > pico) pico = espectros[c][i];
        }
        if (pico > mejor) {
          mejor = pico;
          iBest = i;
        }
      }
      fs.push(f[iBest]);
      for (let c = 0; c < espectros.length; c++) {
        ps[c].push(espectros[c] ? espectros[c][iBest] : NaN);
      }
    }
    return {
      f: Float64Array.from(fs),
      p: ps.map(function (col, c) { return espectros[c] ? Float64Array.from(col) : null; })
    };
  }

  function buscarPicos(env, umbralPct, radio, distMin, nMax) {
    const n = env.length;
    const umbral = umbralPct * maxArray(env);
    const locs = [];
    const picos = [];
    for (let i = radio; i < n - radio; i++) {
      const v = env[i];
      if (v < umbral) continue;
      let esMax = true;
      for (let j = i - radio; j <= i + radio; j++) {
        if (env[j] > v) {
          esMax = false;
          break;
        }
      }
      if (!esMax) continue;
      locs.push(i);
      picos.push(v);
    }
    const orden = locs.map(function (_, i) { return i; }).sort(function (a, b) { return picos[b] - picos[a]; });
    const elegidos = [];
    for (let k = 0; k < orden.length; k++) {
      const loc = locs[orden[k]];
      let lejos = true;
      for (let j = 0; j < elegidos.length; j++) {
        if (Math.abs(loc - elegidos[j]) < distMin) lejos = false;
      }
      if (lejos) elegidos.push(loc);
      if (elegidos.length === nMax) break;
    }
    elegidos.sort(function (a, b) { return a - b; });
    return elegidos;
  }

  function maxArray(x) {
    let m = -Infinity;
    for (let i = 0; i < x.length; i++) if (x[i] > m) m = x[i];
    return m;
  }

  function frecuenciaDeCanal(col, fs, descartar) {
    if (!col || col.length < 256) return { fn: NaN, n: 0, locs: [] };
    const a = tarar(col);
    const radio = Math.max(1, Math.round(0.005 * fs));
    const distMin = Math.round(0.03 * fs);
    const env = movmean(absArray(a), Math.max(1, Math.round(0.005 * fs)));
    let locs = buscarPicos(env, 0.15, radio, distMin, 6);
    if (!locs.length) locs = buscarPicos(env, 0.08, radio, distMin, 6);
    if (descartar >= 1 && descartar <= locs.length) {
      locs = locs.slice(0, descartar - 1).concat(locs.slice(descartar));
    }
    const pre = Math.round(0.02 * fs);
    const tot = Math.round(1.0 * fs);
    const frecs = [];
    locs.forEach(function (loc) {
      const ini = Math.max(0, loc - pre);
      const fin = Math.min(a.length, ini + tot);
      if (fin - ini < 256) return;
      const trozo = a.subarray(ini, fin);
      const spec = fftSimple(trozo, fs);
      let mejor = -Infinity;
      let fMejor = NaN;
      for (let i = 0; i < spec.f.length; i++) {
        if (spec.f[i] >= 20 && spec.f[i] <= 3000 && spec.p[i] > mejor) {
          mejor = spec.p[i];
          fMejor = spec.f[i];
        }
      }
      if (Number.isFinite(fMejor)) frecs.push(fMejor);
    });
    return {
      fn: frecs.length ? frecs.reduce(function (s, v) { return s + v; }, 0) / frecs.length : NaN,
      n: frecs.length,
      locs: locs
    };
  }

  function absArray(x) {
    const y = new Float64Array(x.length);
    for (let i = 0; i < x.length; i++) y[i] = Math.abs(x[i]);
    return y;
  }

  function evaluarChatter(espec, banda) {
    const letras = ["X", "Y", "Z"];
    const chatterEje = [false, false, false];
    const picosF = [NaN, NaN, NaN];
    const picosA = [NaN, NaN, NaN];
    const contrasteEje = [NaN, NaN, NaN];
    const medianasFueraBanda = [NaN, NaN, NaN];
    for (let c = 0; c < 3; c++) {
      const p = espec.p[c];
      if (!p) continue;
      let amp = -Infinity;
      let fAmp = NaN;
      const resto = [];
      for (let i = 0; i < espec.f.length; i++) {
        const f = espec.f[i];
        if (f >= banda[0] && f <= banda[1]) {
          if (p[i] > amp) {
            amp = p[i];
            fAmp = f;
          }
        } else if (f >= 100 && f <= 3000) {
          resto.push(p[i]);
        }
      }
      if (!Number.isFinite(amp)) continue;
      picosA[c] = amp;
      picosF[c] = fAmp;
      const med = median(resto);
      if (Number.isFinite(med)) {
        medianasFueraBanda[c] = med;
        contrasteEje[c] = amp / Math.max(med, 1e-12);
        chatterEje[c] = contrasteEje[c] > 4;
      }
    }
    let cMax = -1;
    let ampModal = NaN;
    for (let c = 0; c < 3; c++) {
      if (Number.isFinite(picosA[c]) && !(picosA[c] < ampModal)) {
        ampModal = picosA[c];
        cMax = c;
      }
    }
    const activos = [];
    chatterEje.forEach(function (v, c) { if (v) activos.push(letras[c]); });
    return {
      fModal: cMax >= 0 ? picosF[cMax] : NaN,
      ampModal: ampModal,
      chatter: activos.length > 0,
      eje: activos.length ? activos.join(", ") : (cMax >= 0 ? letras[cMax] : ""),
      chatterEje: chatterEje,
      contrasteEje: contrasteEje,
      frecuenciaPicoEje: picosF,
      amplitudPicoEje: picosA,
      medianaFueraBandaEje: medianasFueraBanda
    };
  }

  function crecimiento(mag) {
    const ter = Math.floor(mag.length / 3);
    if (ter < 10) return NaN;
    let s1 = 0;
    let s3 = 0;
    for (let i = 0; i < ter; i++) s1 += mag[i] * mag[i];
    for (let i = mag.length - ter; i < mag.length; i++) s3 += mag[i] * mag[i];
    const r1 = Math.sqrt(s1 / ter);
    const r3 = Math.sqrt(s3 / ter);
    return r1 > 0 ? r3 / r1 : NaN;
  }

  function metaDeNombre(nombre) {
    const texto = sinAcento(nombre).toLowerCase();
    const mm = texto.match(/(\d+\.?\d*)\s*mm/);
    let refrigerante = "";
    if (texto.indexOf("sin refrigerante") >= 0) refrigerante = "Sin refrigerante";
    else if (texto.indexOf("con refrigerante") >= 0) refrigerante = "Con refrigerante";
    let herramienta = "";
    if (texto.indexOf("desgastada") >= 0) herramienta = "Desgastada";
    else if (texto.indexOf("nueva") >= 0) herramienta = "Nueva";
    return {
      profundidad: mm ? parseFloat(mm[1]) : NaN,
      refrigerante: refrigerante,
      herramienta: herramienta
    };
  }

  function analizarSenal(armado, banda) {
    const canales = armado.canales.map(function (c) { return c ? tarar(c) : null; });
    const rmsEje = canales.map(rms);
    const mag = magnitud(canales);
    let s = 0;
    for (let i = 0; i < mag.length; i++) s += mag[i] * mag[i];
    const rmsR = mag.length ? Math.sqrt(s / mag.length) : NaN;
    const crudos = [null, null, null];
    let fRef = null;
    for (let c = 0; c < 3; c++) {
      if (!canales[c]) continue;
      const spec = fftSimple(canales[c], armado.fs);
      crudos[c] = spec.p;
      if (!fRef) fRef = spec.f;
    }
    const espec = fRef ? reducirEspectro(fRef, crudos) : { f: new Float64Array(0), p: [null, null, null] };
    const completo = fRef ? { f: fRef, p: crudos } : { f: new Float64Array(0), p: [null, null, null] };
    const ch = evaluarChatter(completo, banda);
    const plot = reducirTiempo(canales, armado.t, armado.fs, 4000);
    return {
      rms: rmsEje,
      rmsR: rmsR,
      razon: crecimiento(mag),
      fModal: ch.fModal,
      ampModal: ch.ampModal,
      chatter: ch.chatter,
      eje: ch.eje,
      chatterEje: ch.chatterEje,
      contrasteEje: ch.contrasteEje,
      frecuenciaPicoEje: ch.frecuenciaPicoEje,
      amplitudPicoEje: ch.amplitudPicoEje,
      medianaFueraBandaEje: ch.medianaFueraBandaEje,
      t: plot.t,
      y: plot.y,
      evol: evolucionRMS(canales, mag, armado.t, 60),
      f: espec.f,
      p: espec.p,
      fs: armado.fs,
      nota: armado.nota
    };
  }

  function analizarModal(armado, descartar) {
    const fn = [NaN, NaN, NaN];
    let n = 0;
    const locs = [null, null, null];
    const textos = [];
    for (let c = 0; c < 3; c++) {
      if (!armado.canales[c]) continue;
      const r = frecuenciaDeCanal(armado.canales[c], armado.fs, descartar);
      fn[c] = r.fn;
      n += r.n;
      locs[c] = r.locs.map(function (i) { return i / armado.fs; });
      if (Number.isFinite(r.fn)) {
        textos.push(["X", "Y", "Z"][c] + " " + r.fn.toFixed(1) + " Hz (" + r.n + " impactos)");
      }
    }
    const plot = reducirTiempo(armado.canales.map(function (c) { return c ? tarar(c) : null; }), armado.t, armado.fs, 4000);
    const usada = median(fn);
    return {
      fn: fn,
      fNatural: usada,
      n: n,
      locs: locs,
      t: plot.t,
      y: plot.y,
      detalle: textos.length ? textos.join("; ") : "no se detectaron impactos útiles",
      banda: Number.isFinite(usada) ? [Math.max(20, usada - 125), usada + 125] : [1300, 1550]
    };
  }

  function indices(pruebas) {
    function maxFin(campo, sub) {
      let m = NaN;
      pruebas.forEach(function (p) {
        const v = sub(p);
        if (Number.isFinite(v) && !(v < m)) m = v;
      });
      return m;
    }
    const refA = maxFin("a", function (p) { return p.rmsA; });
    const refP = maxFin("p", function (p) { return p.ampModal; });
    const refF = maxFin("f", function (p) { return p.rmsF; });
    pruebas.forEach(function (p) {
      let num = 0;
      let den = 0;
      if (Number.isFinite(p.rmsA) && refA > 0) {
        num += 0.45 * (p.rmsA / refA);
        den += 0.45;
      }
      if (Number.isFinite(p.ampModal) && refP > 0) {
        num += 0.35 * (p.ampModal / refP);
        den += 0.35;
      }
      if (Number.isFinite(p.rmsF) && refF > 0) {
        num += 0.20 * (p.rmsF / refF);
        den += 0.20;
      }
      p.indice = den ? num / den : NaN;
      if (p.chatter && Number.isFinite(p.indice)) p.indice += 0.15;
    });
    return pruebas;
  }

  root.ChatterAnalisis = {
    tipoCarpeta: tipoCarpeta,
    ejeDeRuta: ejeDeRuta,
    ordenArchivo: ordenArchivo,
    parseLVM: parseLVM,
    armarXYZ: armarXYZ,
    analizarSenal: analizarSenal,
    analizarModal: analizarModal,
    metaDeNombre: metaDeNombre,
    indices: indices,
    fftSimple: fftSimple
  };
})(typeof globalThis !== "undefined" ? globalThis : this);
