const fs = require("fs");
const path = require("path");
const PptxGenJS = require("pptxgenjs");

const raiz = path.resolve(__dirname, "..");
const figurasDir = path.join(__dirname, "figuras");
const assets = "C:/Users/KZTRDG/.cursor/projects/c-Users-KZTRDG-Documents-Estancia-de-Investigaci-n/assets";
const AZUL = "0658A6";
const TINTA = "1B2838";
const GRIS = "5C6B7C";
const LINEA = "D5E2EE";
const TARJETA = "F4F8FB";
const SUAVE = "E7F0F8";
const FUENTE = "Calibri";
const SALIDA = path.join(__dirname, "Analisis-de-chatter-Tec-de-Monterrey.pptx");

const ARCHIVOS = {
  portada: "c66f2de2-76da-4b4e-97e7-383253a740d0.jpg",
  montaje: "4201b538-7452-4a0e-9754-0e58a67102be.jpg",
  acel: "5aa376d0-4284-43a5-94d7-a35c6036df80.png",
  fuerza: "afe66547-8951-41aa-aa54-c94c45dfae47.png",
  fftAseco: "e5b0da54-282b-4b76-8671-15629b874c4c.png",
  fftAref: "382c3c4f-9753-4e10-b792-517703c6d03a.png",
  fftAagua: "934de682-4fda-403e-9a03-3e04b29be996.png",
  fftFseco: "874efa99-78a8-4d88-80dc-d80d77c5a348.png",
  fftFref: "4e1b54e9-6f02-4fef-a657-c213af66d242.png",
  fftFagua: "c8b778a2-938f-4d2c-b274-ecedba6d2763.png",
  rmsFuerza: "1c2321c1-6aa0-44ec-a555-4cc6ec9477d5.png",
  rugosidad: "638ec210-03c6-4e74-993c-2f8ddd663f87.png"
};

function buscarAsset(fragmento) {
  const nombre = fs.readdirSync(assets).find((archivo) => archivo.includes(fragmento.slice(0, 12)));
  if (!nombre) throw new Error("No está la imagen " + fragmento);
  return path.join(assets, nombre);
}

function canvas() {
  return require(path.join(raiz, "graficas", "node_modules", "@napi-rs", "canvas"));
}

async function prepararFiguras() {
  fs.mkdirSync(figurasDir, { recursive: true });
  const { createCanvas, loadImage } = canvas();
  const portada = await loadImage(buscarAsset(ARCHIVOS.portada));
  const lienzo = createCanvas(portada.width, portada.height);
  const ctx = lienzo.getContext("2d");
  ctx.drawImage(portada, 0, 0);
  const y = Math.floor(portada.height * 0.55);
  const fila = ctx.getImageData(0, y, portada.width, 1).data;
  let corte = Math.floor(portada.width * 0.48);
  for (let x = Math.floor(portada.width * 0.4); x < portada.width; x++) {
    const i = x * 4;
    if (fila[i] < 248 || fila[i + 1] < 248 || fila[i + 2] < 248) {
      corte = Math.max(0, x - 2);
      break;
    }
  }
  const ancho = portada.width - corte;
  const xLogo = corte + Math.floor(ancho * 0.45);
  const anchoLogo = portada.width - xLogo;
  let y0 = 0;
  for (let filaY = 0; filaY < Math.floor(portada.height * 0.45); filaY++) {
    const filaFoto = ctx.getImageData(xLogo, filaY, anchoLogo, 1).data;
    let blancos = 0;
    let muestras = 0;
    for (let x = 0; x < anchoLogo; x += 3) {
      const i = x * 4;
      muestras++;
      if (filaFoto[i] > 248 && filaFoto[i + 1] > 248 && filaFoto[i + 2] > 248) blancos++;
    }
    const fraccion = muestras ? blancos / muestras : 1;
    if (fraccion > 0.9) y0 = filaY + 2;
  }
  const alto = portada.height - y0;
  const foto = createCanvas(ancho, alto);
  foto.getContext("2d").drawImage(portada, corte, y0, ancho, alto, 0, 0, ancho, alto);
  const torno = path.join(figurasDir, "torno.png");
  fs.writeFileSync(torno, foto.toBuffer("image/png"));

  const salidas = { torno: { path: torno, w: ancho, h: alto } };
  for (const [clave, fragmento] of Object.entries(ARCHIVOS)) {
    if (clave === "portada") continue;
    const origen = buscarAsset(fragmento);
    const destino = path.join(figurasDir, clave + path.extname(origen));
    fs.copyFileSync(origen, destino);
    const imagen = await loadImage(destino);
    salidas[clave] = { path: destino, w: imagen.width, h: imagen.height };
  }
  return salidas;
}

async function logoPng() {
  const { createCanvas, loadImage } = canvas();
  const imagen = await loadImage(path.join(raiz, "logo-tec.svg"));
  const lienzo = createCanvas(512, 512);
  lienzo.getContext("2d").drawImage(imagen, 0, 0, 512, 512);
  const destino = path.join(__dirname, "logo-tec.png");
  fs.writeFileSync(destino, lienzo.toBuffer("image/png"));
  return destino;
}

function ajustar(imagen, x, y, w, h) {
  const escala = Math.min(w / imagen.w, h / imagen.h);
  const dw = imagen.w * escala;
  const dh = imagen.h * escala;
  return { x: x + (w - dw) / 2, y: y + (h - dh) / 2, w: dw, h: dh };
}

function crear(logo, figs) {
  const pptx = new PptxGenJS();
  pptx.defineLayout({ name: "WIDE", width: 13.333, height: 7.5 });
  pptx.layout = "WIDE";
  pptx.title = "Dinámica y tribología del torneado: chatter, desgaste y MQL";
  pptx.author = "Manuel Delgado Espinoza";
  pptx.subject = "Estancia de investigación · Tecnológico de Monterrey";
  pptx.company = "Tecnológico de Monterrey";
  let numero = 0;
  const total = 15;

  function pie(slide) {
    slide.addShape(pptx.ShapeType.rect, {
      x: 0.5, y: 7.08, w: 12.32, h: 0.012,
      fill: { color: "E3EDF6" }, line: { color: "E3EDF6" }
    });
    slide.addText("Manuel Delgado Espinoza    ·    Tecnológico de Monterrey", {
      x: 0.5, y: 7.14, w: 9.5, h: 0.24,
      fontFace: FUENTE, fontSize: 11, color: "8A9AAB", margin: 0
    });
    slide.addText(String(numero).padStart(2, "0") + "  /  " + String(total).padStart(2, "0"), {
      x: 10.3, y: 7.14, w: 2.5, h: 0.24,
      fontFace: FUENTE, fontSize: 12, bold: true, color: AZUL, align: "right", margin: 0
    });
  }

  function diapositiva(kicker, titulo, notas, dibujar) {
    const slide = pptx.addSlide();
    numero += 1;
    slide.background = { color: "FFFFFF" };
    slide.addImage({ path: logo, x: 12.32, y: 0.14, w: 0.62, h: 0.62 });
    slide.addText(String(numero).padStart(2, "0") + "   " + kicker.toUpperCase(), {
      x: 0.48, y: 0.14, w: 11.5, h: 0.24,
      fontFace: FUENTE, fontSize: 12, bold: true, color: AZUL, margin: 0, charSpacing: 0.8
    });
    slide.addText(titulo, {
      x: 0.46, y: 0.38, w: 11.6, h: 0.46,
      fontFace: FUENTE, fontSize: 24, bold: true, color: TINTA, margin: 0
    });
    slide.addShape(pptx.ShapeType.rect, {
      x: 0.48, y: 0.92, w: 0.95, h: 0.035,
      fill: { color: AZUL }, line: { color: AZUL }
    });
    dibujar(slide);
    pie(slide);
    slide.addNotes(notas);
  }

  function figura(slide, imagen, x, y, w, h) {
    const caja = ajustar(imagen, x, y, w, h);
    slide.addImage({ path: imagen.path, x: caja.x, y: caja.y, w: caja.w, h: caja.h });
  }

  function lectura(slide, lineas) {
    const alto = 1.78;
    lineas.forEach((linea, i) => {
      const [etiqueta, titulo, cuerpo] = linea.split("|");
      const y = 1.16 + i * 1.9;
      slide.addShape(pptx.ShapeType.rect, {
        x: 0.48, y, w: 4.55, h: alto,
        fill: { color: TARJETA }, line: { color: LINEA, width: 1 }
      });
      slide.addShape(pptx.ShapeType.rect, {
        x: 0.48, y, w: 0.055, h: alto,
        fill: { color: AZUL }, line: { color: AZUL }
      });
      slide.addText(etiqueta, {
        x: 0.7, y: y + 0.12, w: 4.15, h: 0.24,
        fontFace: FUENTE, fontSize: 11, bold: true, color: AZUL, margin: 0, charSpacing: 0.7
      });
      slide.addText(titulo, {
        x: 0.7, y: y + 0.4, w: 4.15, h: 0.62,
        fontFace: FUENTE, fontSize: 15, bold: true, color: TINTA, margin: 0, valign: "top"
      });
      slide.addText(cuerpo, {
        x: 0.7, y: y + 1.05, w: 4.15, h: 0.58,
        fontFace: FUENTE, fontSize: 13, color: GRIS, margin: 0, valign: "top"
      });
    });
  }

  function ficha(slide, x, y, w, h, etiqueta, titulo, cuerpo) {
    slide.addShape(pptx.ShapeType.rect, {
      x, y, w, h, fill: { color: TARJETA }, line: { color: LINEA, width: 1 }
    });
    slide.addText(etiqueta, {
      x: x + 0.16, y: y + 0.12, w: w - 0.32, h: 0.22,
      fontFace: FUENTE, fontSize: 11, bold: true, color: AZUL, margin: 0, charSpacing: 0.6
    });
    slide.addText(titulo, {
      x: x + 0.16, y: y + 0.38, w: w - 0.32, h: 0.42,
      fontFace: FUENTE, fontSize: 15, bold: true, color: TINTA, margin: 0
    });
    slide.addText(cuerpo, {
      x: x + 0.16, y: y + 0.84, w: w - 0.32, h: h - 0.98,
      fontFace: FUENTE, fontSize: 13, color: GRIS, margin: 0, valign: "top"
    });
  }

  function tarjeta(slide, x, y, w, h, titulo, texto) {
    slide.addText([
      { text: titulo, options: { bold: true, fontSize: 14, color: AZUL, breakLine: true } },
      { text: texto, options: { fontSize: 13, color: TINTA } }
    ], {
      x, y, w, h,
      fontFace: FUENTE,
      shape: pptx.ShapeType.roundRect,
      rectRadius: 0.06,
      fill: { color: TARJETA },
      line: { color: LINEA, width: 1 },
      valign: "top",
      margin: 10
    });
  }

  const portada = pptx.addSlide();
  numero = 1;
  portada.background = { color: "FFFFFF" };
  portada.addShape(pptx.ShapeType.rect, {
    x: 0, y: 0, w: 0.12, h: 7.5, fill: { color: AZUL }, line: { color: AZUL }
  });
  portada.addImage({ path: logo, x: 12.28, y: 0.22, w: 0.7, h: 0.7 });
  portada.addText("TECNOLÓGICO DE MONTERREY", {
    x: 0.55, y: 0.42, w: 7.2, h: 0.28,
    fontFace: FUENTE, fontSize: 13, bold: true, color: AZUL, margin: 0, charSpacing: 1.1
  });
  portada.addText("Dinámica y tribología\ndel torneado:\nchatter, desgaste y MQL", {
    x: 0.52, y: 0.85, w: 7.3, h: 2.15,
    fontFace: FUENTE, fontSize: 32, bold: true, color: TINTA, margin: 0
  });
  portada.addText("Cuando se tornea, la herramienta puede vibrar. Este avance muestra qué se midió y qué todavía no se puede afirmar.", {
    x: 0.55, y: 3.15, w: 6.9, h: 0.85,
    fontFace: FUENTE, fontSize: 16, color: GRIS, margin: 0
  });
  portada.addShape(pptx.ShapeType.rect, {
    x: 0.55, y: 4.12, w: 1.15, h: 0.025, fill: { color: AZUL }, line: { color: AZUL }
  });
  portada.addText("14 pruebas   ·   2,5 mm de profundidad   ·   tres condiciones medidas", {
    x: 0.55, y: 4.28, w: 6.9, h: 0.28,
    fontFace: FUENTE, fontSize: 13, color: "8A9AAB", margin: 0
  });
  portada.addText("Manuel Delgado Espinoza", {
    x: 0.55, y: 5.05, w: 6.9, h: 0.36,
    fontFace: FUENTE, fontSize: 20, bold: true, color: TINTA, margin: 0
  });
  portada.addText("7.º semestre de Ingeniería Mecánica\nProfesor: César David Reséndiz Calderón", {
    x: 0.55, y: 5.45, w: 6.9, h: 0.7,
    fontFace: FUENTE, fontSize: 15, color: GRIS, margin: 0
  });
  figura(portada, figs.torno, 7.55, 1.15, 5.15, 5.55);
  pie(portada);
  portada.addNotes(
    "Preséntate y lee el título despacio. No des por conocida ninguna palabra.\n\n" +
    "Dinámica: cómo se mueve la herramienta. Tribología: el contacto, el roce y el desgaste entre el filo y la pieza. Chatter: una vibración del corte. MQL significa lubricación con muy poco aceite; en las láminas no usamos esa etiqueta.\n\n" +
    "Di la frase de abajo: vamos a ver qué se midió y qué todavía no se puede afirmar. Las condiciones se nombran como se midieron: sin refrigerante, con refrigerante y con agua.\n\nTiempo: 40 segundos."
  );

  diapositiva("Antes de empezar", "Chatter regenerativo: el corte se alimenta",
    "Nómbralo con precisión: chatter regenerativo. No es cualquier vibración del torno.\n\n" +
    "1. La herramienta tiene un modo propio. En este montaje, en X y en reposo, está cerca de 293 Hz. El corte puede excitarlo.\n" +
    "2. Al vibrar, el filo cambia el espesor de viruta y deja una ondulación.\n" +
    "3. En la vuelta siguiente corta esa onda. Si la fase coincide, la vibración crece. Por eso se regenera: la pasada anterior alimenta la actual.\n\n" +
    "Distingue la alerta del fenómeno. La alerta solo dice que un pico destaca junto a ese modo, entre 168 y 418 Hz. Confirmar chatter exige ver la onda en la pieza.\n\nTiempo: 70 segundos.",
    (slide) => {
      const pasos = [
        ["01", "Excita su modo", "El filo tiene una frecuencia propia, cerca de 293 Hz en X. El corte puede ponerla a oscilar."],
        ["02", "Modula la viruta", "Esa oscilación cambia el espesor que se corta y deja una ondulación en la pieza."],
        ["03", "La vuelta lo regenera", "El filo recorta esa onda. Si la fase coincide, la vibración crece: chatter regenerativo."]
      ];
      pasos.forEach((paso, i) => {
        const x = 0.48 + i * 4.2;
        slide.addShape(pptx.ShapeType.rect, {
          x, y: 1.16, w: 4.02, h: 2.05,
          fill: { color: "FFFFFF" }, line: { color: LINEA, width: 1 }
        });
        slide.addShape(pptx.ShapeType.rect, {
          x, y: 1.16, w: 4.02, h: 0.055, fill: { color: AZUL }, line: { color: AZUL }
        });
        slide.addText(paso[0], {
          x: x + 0.18, y: 1.34, w: 3.6, h: 0.28,
          fontFace: FUENTE, fontSize: 12, bold: true, color: AZUL, margin: 0, charSpacing: 0.8
        });
        slide.addText(paso[1], {
          x: x + 0.18, y: 1.68, w: 3.64, h: 0.42,
          fontFace: FUENTE, fontSize: 16, bold: true, color: TINTA, margin: 0
        });
        slide.addText(paso[2], {
          x: x + 0.18, y: 2.16, w: 3.64, h: 0.85,
          fontFace: FUENTE, fontSize: 13, color: GRIS, margin: 0
        });
      });
      slide.addShape(pptx.ShapeType.rect, {
        x: 0.48, y: 3.38, w: 12.36, h: 0.72,
        fill: { color: SUAVE }, line: { color: LINEA, width: 1 }
      });
      slide.addText("No está confirmado. La alerta solo marca un pico junto a ese modo, de 168 a 418 Hz. Falta la ondulación en la pieza.", {
        x: 0.68, y: 3.48, w: 12.0, h: 0.52,
        fontFace: FUENTE, fontSize: 14, color: TINTA, margin: 0, valign: "middle"
      });
      ficha(slide, 0.48, 4.55, 3.02, 1.85, "TORNEADO", "La pieza gira", "El filo le quita una capa de metal. Aquí esa profundidad es de 2,5 mm.");
      ficha(slide, 3.66, 4.55, 3.02, 1.85, "DESGASTE", "Filo nuevo y usado", "Se comparan los dos. No se midió cuántos milímetros se gastó el filo.");
      ficha(slide, 6.84, 4.55, 3.02, 1.85, "CONDICIONES", "Cómo se midieron", "Sin refrigerante, con refrigerante y con agua. El título dice MQL; las láminas no.");
      ficha(slide, 10.02, 4.55, 2.82, 1.85, "UNIDADES", "g, volts y Ra", "Vibración en g. Fuerza en volts, no en newtons. Ra más bajo es más liso.");
    }
  );

  diapositiva("Montaje", "Dónde se mide cada cosa",
    "Recorre la imagen de izquierda a derecha y di una frase por cada aparato, sin siglas.\n\n" +
    "Izquierda, el torno: la pieza gira y el filo corta. El acelerómetro está en la herramienta y siente el temblor en tres direcciones, X, Y y Z. Esas mismas letras salen en todas las gráficas. El dinamómetro está en el soporte de la herramienta y siente el empuje del corte.\n\n" +
    "Derecha, el camino de los datos: el sensor produce una señal eléctrica, el equipo la convierte en números y la computadora la guarda. El dibujo explica ese recorrido. No es una foto del cableado real.\n\nTiempo: 50 segundos.",
    (slide) => {
      ficha(slide, 0.48, 1.12, 4.02, 1.52, "01  ACELERÓMETRO", "En la herramienta", "Aceleración en X, Y y Z. El modo de 293 Hz se identificó en X, en reposo.");
      ficha(slide, 4.66, 1.12, 4.02, 1.52, "02  DINAMÓMETRO", "En el soporte", "Fuerza de corte en tres ejes. La señal sigue en volts, sin pasar a newtons.");
      ficha(slide, 8.84, 1.12, 4.02, 1.52, "03  REGISTRO", "De la señal al archivo", "Sensor, equipo y computadora. El esquema no es el cableado real.");
      figura(slide, figs.montaje, 0.48, 2.8, 12.36, 4.1);
    }
  );

  diapositiva("Aceleración", "El temblor, segundo a segundo",
    "Di primero qué es la gráfica: no es una foto, es el temblor de la herramienta a lo largo del corte. El tiempo va de izquierda a derecha. Si la línea se aleja del cero, la herramienta acelera más.\n\n" +
    "Es una sola prueba: filo nuevo, 2,5 mm, sin refrigerante, de 7 a 35 segundos.\n\n" +
    "El RMS resume la energía de toda la señal: X 3,05 g, Y 0,54 g y Z 3,72 g. Aclara que el RMS no diagnostica chatter. El chatter se busca en la frecuencia, no en este promedio.\n\n" +
    "La señal se atenúa: al final queda en 0,47 de la del inicio. Un chatter regenerativo, si se ha acoplado, tiende a crecer o a sostenerse. Aquí decae. Las tres gráficas de abajo comparten escala.\n\nTiempo: 55 segundos.",
    (slide) => {
      lectura(slide, [
        "QUÉ PRUEBA|Filo nuevo, 2,5 mm, sin refrigerante|De 7 a 35 s. Sirve para ver si la vibración crece.",
        "CÓMO SE LEE|RMS es energía total, no chatter|X 3,05 g y Z 3,72 g. Y queda en 0,54 g.",
        "QUÉ SE VE|Decae: no parece regenerativo|Al final vale 0,47 del inicio. El chatter suele crecer."
      ]);
      figura(slide, figs.acel, 5.25, 1.12, 7.55, 5.8);
    }
  );

  diapositiva("Fuerza", "El empuje del corte, en volts",
    "Es la misma prueba. Ahora no medimos movimiento, sino cuánto empuja el filo. Fx, Fy y Fz son las tres direcciones de esa fuerza.\n\n" +
    "La unidad es volts: la señal eléctrica del sensor. RMS: Fx 1,13 V, Fy 1,04 V y Fz 0,80 V. Di en voz alta que no está pasada a newtons. Un volt más alto todavía no se puede llamar más newtons.\n\n" +
    "Hay un pico cuando la herramienta entra al corte y después la señal se queda cerca de 1 V. El tramo de tiempo no es el de la vibración, así que no se ponen una encima de la otra.\n\nTiempo: 50 segundos.",
    (slide) => {
      lectura(slide, [
        "MISMA PRUEBA|Fuerza de corte, no aceleración|Fx, Fy y Fz. El pico inicial es la entrada del filo.",
        "UNIDAD|Volts: aún no hay coeficiente de corte|RMS: Fx 1,13 V, Fy 1,04 V y Fz 0,80 V.",
        "QUÉ SE VE|Tras la entrada, el corte se asienta|Cerca de 1 V. No es el mismo tramo que la vibración."
      ]);
      figura(slide, figs.fuerza, 5.25, 1.12, 7.55, 5.8);
    }
  );

  const espectros = [
    ["fftAseco", "Vibración, seco", "Sin refrigerante: en qué ritmo vibra",
      "QUÉ ES|Espectro: energía por frecuencia|Separa la vibración forzada de la cercana al modo.",
      "LA ALERTA|Ventana del modo de la herramienta|293 Hz en X, en reposo. Se revisa de 168 a 418 Hz.",
      "EN ESTA CONDICIÓN|366 Hz en Z cae dentro del modo|Sobre 2 000 Hz hay otro pico. No es esta alerta.",
      "Di que un espectro reparte la vibración por frecuencia. La alerta no mira el pico más alto de toda la gráfica: mira si hay energía junto al modo de la herramienta, medido en reposo a 293 Hz en X, entre 168 y 418 Hz.\n\n" +
      "Señala Z con filo nuevo: 366 Hz cae en esa ventana. Un pico por encima de 2 000 Hz puede ser más alto y, aun así, no es la alerta. No leas los recuadros.\n\nTiempo: 55 segundos."],
    ["fftAref", "Vibración, refrigerante", "Con refrigerante: el ritmo del temblor",
      "QUÉ CAMBIA|Ahora el corte lleva refrigerante|Izquierda, filo nuevo. Derecha, filo usado.",
      "DÓNDE ESTÁ EL PICO|El máximo global no es el modo|Queda entre 2 000 y 2 600 Hz. El modo es menor.",
      "CÓMO LEERLO|Si un pico tapa al resto, la escala se comprime|No compares alturas entre escalas distintas.",
      "El criterio no cambia con el fluido: se busca el modo, no el pico más alto. Con refrigerante ese máximo queda entre 2 000 y 2 600 Hz, lejos de 293 Hz.\n\n" +
      "Azul es la primera prueba y amarillo la segunda. Si la escala cambia para que un pico enorme no tape a los demás, no compares la altura con otra lámina.\n\nTiempo: 45 segundos."],
    ["fftAagua", "Vibración, agua", "Con agua: el ritmo del temblor",
      "QUÉ CAMBIA|El corte es con agua|Tres pruebas por herramienta. El color las distingue.",
      "QUÉ NO ES LA ALERTA|En X, filo usado, el pico es lento|Baja frecuencia: queda fuera del modo, 168 a 418 Hz.",
      "EL EJE Y|Se mueve menos que X y que Z|Se ve igual que en la gráfica del tiempo.",
      "Di que el color es el número de prueba. Señala el pico lento y grande de X con filo usado y aclara que no es la zona de la alerta. Cierra recordando que Y casi no se mueve, como ya se vio en el tiempo.\n\nTiempo: 40 segundos."],
    ["fftFseco", "Fuerza, seco", "Sin refrigerante: el ritmo del empuje",
      "QUÉ CAMBIA|Ahora es la fuerza, no el temblor|Sigue en volts. No está pasada a newtons.",
      "QUÉ SE DEJA FUERA|Se retira la componente estática|Por debajo de 2 Hz es empuje quieto, no vibración.",
      "QUÉ NO CONCLUIR|Fuerza y aceleración no coinciden|El pico del modo rara vez es el máximo del espectro.",
      "Aclara el cambio: pasamos de movimiento a empuje, y la unidad sigue siendo volts. El empuje que no vibra se deja fuera, por eso la gráfica no empieza en cero.\n\n" +
      "El pico más alto y el pico de la zona vigilada no tienen por qué ser el mismo.\n\nTiempo: 45 segundos."],
    ["fftFref", "Fuerza, refrigerante", "Con refrigerante: el ritmo del empuje",
      "QUÉ COMPARAR|Filo nuevo a la izquierda, usado a la derecha|Primero mira si las dos pruebas se parecen.",
      "DENTRO DE LA ZONA|180 Hz sí cae en el modo|Está entre 168 y 418 Hz. No confirma la onda.",
      "FUERA DE LA ZONA|60 Hz puede ser la red eléctrica|Es vibración forzada, no chatter regenerativo.",
      "Pide a la audiencia que compare las dos repeticiones antes de leer un número. 180 Hz está dentro de la zona vigilada. 60 Hz puede ser la corriente del laboratorio: dilo como posibilidad, no como chatter.\n\nTiempo: 40 segundos."],
    ["fftFagua", "Fuerza, agua", "Con agua: el ritmo del empuje",
      "QUÉ MUESTRA|Fuerza con agua, todavía en volts|Tres pruebas por herramienta. El color dice cuál es.",
      "DENTRO DE LA ZONA|373 Hz queda junto al modo|Cae entre 168 y 418 Hz. El máximo global puede ser otro.",
      "QUÉ NO CONCLUIR|Ni newtons ni chatter confirmado|Un pico en la ventana no sustituye la marca en la pieza.",
      "Cierra el bloque de frecuencias con la misma cautela: 373 Hz cae dentro de la zona, pero el pico más alto de la gráfica puede ser otro. No conviertas ese pico en newtons ni en chatter confirmado.\n\nTiempo: 40 segundos."]
  ];

  espectros.forEach((item) => {
    const [clave, kicker, titulo, a, b, c, notas] = item;
    diapositiva(kicker, titulo, notas, (slide) => {
      lectura(slide, [a, b, c]);
      figura(slide, figs[clave], 5.25, 1.12, 7.55, 5.8);
    });
  });

  diapositiva("Comparación", "Cada prueba empuja distinto",
    "Explica la gráfica antes de señalar la barra alta. Cada grupo de tres barras es una prueba completa, no un promedio. Azul, rojo y verde son las tres direcciones de la fuerza. La altura es RMS en volts: un resumen de qué tan fuerte fue el empuje.\n\n" +
    "Señala la segunda prueba con filo nuevo y sin refrigerante. La barra verde se dispara, cerca de 7 V. Una sola repetición no representa la condición.\n\n" +
    "Por eso no se puede decir, con esta lámina, que un fluido siempre sube o baja la fuerza.\n\nTiempo: 45 segundos.",
    (slide) => {
      const hechos = [
        ["CADA GRUPO", "Es una prueba completa, no un promedio de la condición."],
        ["LOS COLORES", "Azul, rojo y verde son Fx, Fy y Fz. La unidad sigue en volts."],
        ["LA EXCEPCIÓN", "La segunda prueba nueva, en seco, llega cerca de 7 V en Fz."]
      ];
      hechos.forEach((hecho, i) => {
        const x = 0.48 + i * 4.2;
        slide.addText(hecho[0], {
          x, y: 1.12, w: 4.0, h: 0.22,
          fontFace: FUENTE, fontSize: 11, bold: true, color: AZUL, margin: 0, charSpacing: 0.6
        });
        slide.addText(hecho[1], {
          x, y: 1.36, w: 4.0, h: 0.48,
          fontFace: FUENTE, fontSize: 14, color: TINTA, margin: 0
        });
      });
      figura(slide, figs.rmsFuerza, 0.48, 2.0, 12.36, 4.9);
    }
  );

  diapositiva("Superficie", "Qué tan lisa quedó la pieza",
    "Define Ra antes de leer números: es la rugosidad media, qué tan áspera quedó la superficie. Se mide en micrómetros, milésimas de milímetro. Más bajo es más lisa.\n\n" +
    "La línea sobre la barra dice qué tanto se separan las pruebas. Si es larga, el promedio es menos firme. Lee también la tabla.\n\n" +
    "Filo nuevo con refrigerante: 2,70 µm, la más baja, pero con mucha dispersión y solo dos pruebas. Filo usado con refrigerante: 5,80 µm, más áspera y más pareja. En seco los promedios se parecen, 4,55 y 4,61 µm, y las pruebas se separan. Con agua hay una sola serie: 5,35 µm nueva y 4,39 µm desgastada.\n\n" +
    "Cierra con la advertencia: estas rugosidades no son los mismos archivos de la vibración.\n\nTiempo: 55 segundos.",
    (slide) => {
      const hechos = [
        ["QUÉ ES Ra", "Rugosidad media, en micrómetros. Más bajo es más lisa."],
        ["QUÉ MEZCLA", "No es solo vibración: también entran el avance y la geometría del filo."],
        ["OJO", "Estas series no son los mismos archivos de la aceleración."]
      ];
      hechos.forEach((hecho, i) => {
        const x = 0.48 + i * 4.2;
        slide.addText(hecho[0], {
          x, y: 1.12, w: 4.0, h: 0.22,
          fontFace: FUENTE, fontSize: 11, bold: true, color: AZUL, margin: 0, charSpacing: 0.6
        });
        slide.addText(hecho[1], {
          x, y: 1.36, w: 4.0, h: 0.46,
          fontFace: FUENTE, fontSize: 14, color: TINTA, margin: 0
        });
      });
      figura(slide, figs.rugosidad, 0.7, 1.95, 11.9, 4.95);
    }
  );

  diapositiva("Resultado", "Lo que sí se puede decir",
    "Empieza por el criterio, no por el número más bajo. Se recomienda sin refrigerante porque el proceso es robusto al desgaste: 4,3 g con filo nuevo y 4,3 g con filo usado.\n\n" +
    "El refrigerante no es un efecto único. Con filo nuevo da lo más bajo del conjunto, 3,2 g y Ra 2,70 µm. Con filo usado da lo más alto, 6,5 g y Ra 5,80 µm. Eso es interacción filo-fluido.\n\n" +
    "El agua queda cerca de 5 g con los dos filos. No es la peor, pero tampoco acerca el corte al nivel más quieto.\n\n" +
    "Cierra con la cautela: el RMS no detecta chatter. La alerta mira un pico junto al modo y se enciende en las 14 pruebas. Hay de 2 a 4 ensayos por condición.\n\nTiempo: 70 segundos.",
    (slide) => {
      const columnas = [
        {
          recomendada: true,
          etiqueta: "RECOMENDADA",
          titulo: "Sin refrigerante",
          nuevo: "4,3 g",
          usado: "4,3 g",
          ra: "Ra  4,55  ·  4,61 µm",
          nota: "Robusta al desgaste: el mismo nivel con filo nuevo y con filo usado."
        },
        {
          recomendada: false,
          etiqueta: "DEPENDE DEL FILO",
          titulo: "Con refrigerante",
          nuevo: "3,2 g",
          usado: "6,5 g",
          ra: "Ra  2,70  ·  5,80 µm",
          nota: "Interacción filo-fluido: mejora el filo nuevo y castiga el usado."
        },
        {
          recomendada: false,
          etiqueta: "INTERMEDIA",
          titulo: "Con agua",
          nuevo: "5,1 g",
          usado: "5,3 g",
          ra: "Ra  5,35  ·  4,39 µm",
          nota: "No acerca el corte al modo más quieto. Queda entre las otras dos."
        }
      ];
      columnas.forEach((col, i) => {
        const x = 0.48 + i * 4.2;
        slide.addShape(pptx.ShapeType.rect, {
          x, y: 1.16, w: 4.02, h: 3.55,
          fill: { color: col.recomendada ? SUAVE : "FFFFFF" },
          line: { color: col.recomendada ? AZUL : LINEA, width: col.recomendada ? 1.5 : 1 }
        });
        slide.addShape(pptx.ShapeType.rect, {
          x, y: 1.16, w: 4.02, h: 0.08,
          fill: { color: col.recomendada ? AZUL : "C5D4E4" },
          line: { color: col.recomendada ? AZUL : "C5D4E4" }
        });
        slide.addText(col.etiqueta, {
          x: x + 0.2, y: 1.36, w: 3.62, h: 0.24,
          fontFace: FUENTE, fontSize: 11, bold: true, color: AZUL, margin: 0, charSpacing: 0.8
        });
        slide.addText(col.titulo, {
          x: x + 0.2, y: 1.62, w: 3.62, h: 0.36,
          fontFace: FUENTE, fontSize: 18, bold: true, color: TINTA, margin: 0
        });
        slide.addText("Filo nuevo", {
          x: x + 0.2, y: 2.14, w: 1.7, h: 0.22,
          fontFace: FUENTE, fontSize: 12, color: GRIS, margin: 0
        });
        slide.addText("Filo usado", {
          x: x + 2.05, y: 2.14, w: 1.7, h: 0.22,
          fontFace: FUENTE, fontSize: 12, color: GRIS, margin: 0
        });
        slide.addText(col.nuevo, {
          x: x + 0.2, y: 2.36, w: 1.7, h: 0.46,
          fontFace: FUENTE, fontSize: 26, bold: true, color: TINTA, margin: 0
        });
        slide.addText(col.usado, {
          x: x + 2.05, y: 2.36, w: 1.7, h: 0.46,
          fontFace: FUENTE, fontSize: 26, bold: true, color: TINTA, margin: 0
        });
        slide.addText(col.ra, {
          x: x + 0.2, y: 3.0, w: 3.62, h: 0.3,
          fontFace: FUENTE, fontSize: 13, color: GRIS, margin: 0
        });
        slide.addShape(pptx.ShapeType.rect, {
          x: x + 0.2, y: 3.42, w: 3.62, h: 0.012,
          fill: { color: LINEA }, line: { color: LINEA }
        });
        slide.addText(col.nota, {
          x: x + 0.2, y: 3.56, w: 3.62, h: 0.85,
          fontFace: FUENTE, fontSize: 14, color: TINTA, margin: 0
        });
      });
      slide.addShape(pptx.ShapeType.rect, {
        x: 0.48, y: 4.9, w: 12.36, h: 1.32,
        fill: { color: TARJETA }, line: { color: LINEA, width: 1 }
      });
      slide.addText("CÓMO LEER LA COMPARACIÓN", {
        x: 0.72, y: 5.08, w: 11.9, h: 0.24,
        fontFace: FUENTE, fontSize: 11, bold: true, color: AZUL, margin: 0, charSpacing: 0.7
      });
      slide.addText("Se recomienda por robustez ante el desgaste, no por el mínimo aislado. El RMS no es la alerta: la alerta busca un pico junto al modo y se enciende en las 14 pruebas. Preliminar, con 2 a 4 ensayos por condición.", {
        x: 0.72, y: 5.36, w: 11.9, h: 0.72,
        fontFace: FUENTE, fontSize: 15, color: TINTA, margin: 0
      });
    }
  );

  diapositiva("Alcance", "Lo que estas pruebas todavía no dicen",
    "Léela como el límite del dominio, no como una disculpa.\n\n" +
    "1. Chatter regenerativo se confirma con la onda en la pieza, separada por la velocidad de corte dividida entre la frecuencia. La alerta no hace esa prueba.\n" +
    "2. Sin calibrar el dinamómetro no hay fuerza en newtons ni coeficiente de corte.\n" +
    "3. El fluido interactúa con el estado del filo. No se puede recomendar el refrigerante en abstracto.\n" +
    "4. Ra mezcla la vibración con el avance y la geometría del filo, y además sale de otros archivos.\n\n" +
    "Cierra y abre preguntas.\n\nTiempo: 55 segundos.",
    (slide) => {
      const limites = [
        ["01", "No confirma el regenerativo", "La alerta solo dice que un pico destaca junto al modo. Falta la onda en la pieza: su paso es la velocidad de corte dividida entre esa frecuencia."],
        ["02", "No hay coeficiente de corte", "En volts no se pasa a newtons ni se calcula la fuerza específica. La calibración del dinamómetro sigue pendiente."],
        ["03", "El fluido no actúa solo", "Interactúa con el filo. Con filo nuevo el refrigerante acompaña lo más bajo; con filo usado, lo más alto."],
        ["04", "Ra no aísla la vibración", "También pesan el avance y la geometría del filo, y aquí no se separan. Además, no son los mismos archivos."]
      ];
      limites.forEach((punto, i) => {
        const col = i % 2;
        const fila = Math.floor(i / 2);
        const x = 0.48 + col * 6.4;
        const y = 1.16 + fila * 2.05;
        slide.addShape(pptx.ShapeType.rect, {
          x, y, w: 6.2, h: 1.92,
          fill: { color: "FFFFFF" }, line: { color: LINEA, width: 1 }
        });
        slide.addShape(pptx.ShapeType.rect, {
          x, y, w: 0.06, h: 1.92, fill: { color: AZUL }, line: { color: AZUL }
        });
        slide.addText(punto[0], {
          x: x + 0.24, y: y + 0.16, w: 0.7, h: 0.28,
          fontFace: FUENTE, fontSize: 13, bold: true, color: AZUL, margin: 0
        });
        slide.addText(punto[1], {
          x: x + 0.95, y: y + 0.14, w: 4.95, h: 0.32,
          fontFace: FUENTE, fontSize: 16, bold: true, color: TINTA, margin: 0
        });
        slide.addText(punto[2], {
          x: x + 0.24, y: y + 0.62, w: 5.7, h: 1.1,
          fontFace: FUENTE, fontSize: 14, color: GRIS, margin: 0
        });
      });
      slide.addShape(pptx.ShapeType.rect, {
        x: 0.48, y: 5.4, w: 12.36, h: 1.4,
        fill: { color: AZUL }, line: { color: AZUL }
      });
      slide.addText("Hasta aquí llega lo que estas mediciones sostienen.", {
        x: 0.74, y: 5.62, w: 8.4, h: 0.4,
        fontFace: FUENTE, fontSize: 15, color: "D6E6F5", margin: 0
      });
      slide.addText("Preguntas", {
        x: 0.72, y: 6.0, w: 8.4, h: 0.5,
        fontFace: FUENTE, fontSize: 26, bold: true, color: "FFFFFF", margin: 0
      });
    }
  );

  if (numero !== total) throw new Error("Se esperaban " + total + " láminas y hay " + numero + ".");
  return pptx.writeFile({ fileName: SALIDA });
}

Promise.all([logoPng(), prepararFiguras()])
  .then(([logo, figs]) => crear(logo, figs))
  .then(() => console.log("LISTO " + SALIDA))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
