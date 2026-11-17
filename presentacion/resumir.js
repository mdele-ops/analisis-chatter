const fs = require("fs");
const path = require("path");
const vm = require("vm");

const root = path.resolve(__dirname, "..");
const codigo = fs.readFileSync(path.join(root, "analisis.js"), "utf8");
const contexto = { console };
vm.createContext(contexto);
vm.runInContext(codigo, contexto);
const CA = contexto.ChatterAnalisis;
if (!CA) throw new Error("No se cargó el análisis.");

const catalogo = JSON.parse(fs.readFileSync(path.join(root, "datos", "catalogo.json"), "utf8"));

function leerGrupo(rutas) {
  const leidos = [];
  for (const rel of rutas) {
    const texto = fs.readFileSync(path.join(root, rel), "utf8");
    const datos = CA.parseLVM(texto, path.basename(rel));
    leidos.push({
      nombre: path.basename(rel),
      orden: CA.ordenArchivo(rel),
      eje: CA.ejeDeRuta(rel),
      datos
    });
  }
  return CA.armarXYZ(leidos, "X");
}

function num(v) {
  return Number.isFinite(v) ? Math.round(v * 1000) / 1000 : null;
}

function nums(a) {
  return (a || []).map(num);
}

const modal = CA.analizarModal(leerGrupo(catalogo.pruebas[0].modal), 0);
const salida = {
  modal: {
    fn: nums(modal.fn),
    fNatural: num(modal.fNatural),
    banda: modal.banda.map(num),
    detalle: modal.detalle,
    impactos: modal.n
  },
  pruebas: []
};

for (const prueba of catalogo.pruebas) {
  const t0 = Date.now();
  const item = {
    id: prueba.id,
    nombre: prueba.nombre,
    herramienta: prueba.herramienta,
    refrigerante: prueba.refrigerante,
    repeticion: prueba.repeticion
  };
  try {
    const resA = CA.analizarSenal(leerGrupo(prueba.aceleracion), modal.banda);
    item.rms = nums(resA.rms);
    item.rmsA = num(resA.rmsR);
    item.chatter = resA.chatter;
    item.eje = resA.eje;
    item.contraste = nums(resA.contrasteEje);
    item.fPico = nums(resA.frecuenciaPicoEje);
    item.razon = num(resA.razon);
    item.ampModal = num(resA.ampModal);
  } catch (error) {
    item.errorA = error.message;
  }
  try {
    const resF = CA.analizarSenal(leerGrupo(prueba.fuerza), modal.banda, true);
    item.rmsF = nums(resF.rms);
    item.rmsFR = num(resF.rmsR);
  } catch (error) {
    item.errorF = error.message;
  }
  salida.pruebas.push(item);
  console.log(
    prueba.id,
    ((Date.now() - t0) / 1000).toFixed(1) + "s",
    item.chatter ? "alerta " + item.eje : "sin alerta",
    "rmsA", item.rmsA,
    item.errorA || item.errorF || ""
  );
}

fs.writeFileSync(path.join(__dirname, "resultados.json"), JSON.stringify(salida, null, 2));
console.log("LISTO");
