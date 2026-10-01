function Analisis_Chatter_Torneado()
% ANALISIS DE CHATTER EN TORNEADO CONVENCIONAL
%
% Compara en qué condición de corte aparece chatter y cuál es más
% favorable para que la herramienta dure más:
%   - con refrigerante o sin refrigerante
%   - herramienta nueva o desgastada
%   - profundidad 0.5, 1, 2, 2.5 y 3 mm (u otra)
%
% Lee archivos .lvm de aceleración (A*.lvm), fuerza (F*.lvm) y
% análisis modal por impactos (A*.lvm). También permite capturar
% métricas a mano.
%
% Uso:
%   >> Analisis_Chatter_Torneado
%
% No requiere toolboxes adicionales.

fondo = [0.94 0.94 0.94];
rutaCatalogo = fullfile(fileparts(mfilename('fullpath')), 'catalogo_chatter.mat');
pruebas = repmat(plantillaPrueba(), 0, 1);
filaSel = [];
filasSel = [];

fig = figure( ...
    'Name', 'Análisis de chatter en torneado', ...
    'NumberTitle', 'off', ...
    'MenuBar', 'none', ...
    'ToolBar', 'none', ...
    'Color', fondo, ...
    'Position', [70 40 1320 780], ...
    'Resize', 'on');

menuArchivo = uimenu(fig, 'Label', 'Archivo');
uimenu(menuArchivo, 'Label', 'Guardar catálogo', 'Callback', @guardar);
uimenu(menuArchivo, 'Label', 'Guardar catálogo como...', 'Callback', @guardarComo);
uimenu(menuArchivo, 'Label', 'Cargar catálogo', 'Callback', @cargar);
uimenu(menuArchivo, 'Label', 'Exportar resumen CSV', 'Callback', @exportarCsv);
uimenu(menuArchivo, 'Label', 'Crear carpetas de trabajo', 'Callback', @crearCarpetas);
uimenu(menuArchivo, 'Label', 'Eliminar prueba seleccionada', 'Callback', @eliminar);

panel = uipanel( ...
    'Parent', fig, ...
    'Units', 'normalized', ...
    'Position', [0.008 0.065 0.275 0.925], ...
    'BackgroundColor', fondo, ...
    'BorderType', 'line');

y = 0.985;
[H.lblTitulo, y] = uiTexto(panel, y, 'Agregar datos', 0.038);
set(H.lblTitulo, 'FontSize', 13, 'FontWeight', 'bold');

[H.lblAyuda, y] = uiTexto(panel, y, ...
    {'Registra cada pasada del torno.', ...
     'Profundidades previstas: 0.5, 1, 2, 2.5 y 3 mm.'}, 0.058);

[~, y] = uiTexto(panel, y, 'Nombre de la prueba (opcional)', 0.024);
[H.edNombre, y] = uiEdit(panel, y, '', 0.034);

[~, y] = uiTexto(panel, y, 'Profundidad de corte', 0.024);
alto = 0.036;
H.popProf = uicontrol('Parent', panel, 'Style', 'popupmenu', ...
    'String', {'0.5 mm', '1 mm', '2 mm', '2.5 mm', '3 mm', 'Otra'}, ...
    'Units', 'normalized', 'Position', [0.04, y - alto, 0.46, alto], ...
    'BackgroundColor', 'white', 'FontSize', 9, ...
    'Callback', @alCambiarProf);
H.edOtra = uicontrol('Parent', panel, 'Style', 'edit', 'String', '', ...
    'Units', 'normalized', 'Position', [0.54, y - alto, 0.42, alto], ...
    'BackgroundColor', 'white', 'FontSize', 9, 'Enable', 'off', ...
    'TooltipString', 'Si eliges Otra, escribe la profundidad en mm');
y = y - alto - 0.008;

[~, y] = uiTexto(panel, y, 'Refrigerante', 0.024);
[H.popRef, y] = uiPopup(panel, y, {'Sin refrigerante', 'Con refrigerante'}, 0.036);

[~, y] = uiTexto(panel, y, 'Herramienta', 0.024);
[H.popHerr, y] = uiPopup(panel, y, {'Nueva', 'Desgastada'}, 0.036);

[~, y] = uiTexto(panel, y, 'Eje del velocímetro / acelerómetro', 0.024);
[H.popEje, y] = uiPopup(panel, y, {'X', 'Y', 'Z', 'XYZ', 'No especificado'}, 0.036);

[~, y] = uiTexto(panel, y, 'Observaciones', 0.024);
[H.edNotas, y] = uiEdit(panel, y, '', 0.034);

[H.btnA, y] = uiBoton(panel, y, 'Carpeta de aceleración (A*.lvm)', 0.036, @elegirA);
[H.lblA, y] = uiTexto(panel, y, 'Aceleración: (no seleccionada)', 0.022);

[H.btnF, y] = uiBoton(panel, y, 'Carpeta de fuerza (F*.lvm)', 0.036, @elegirF);
[H.lblF, y] = uiTexto(panel, y, 'Fuerza: (no seleccionada)', 0.022);

alto = 0.036;
H.btnM = uicontrol('Parent', panel, 'Style', 'pushbutton', ...
    'String', 'Carpeta modal', ...
    'Units', 'normalized', 'Position', [0.04, y - alto, 0.46, alto], ...
    'FontSize', 9, 'Callback', @elegirM);
H.edDesc = uicontrol('Parent', panel, 'Style', 'edit', 'String', '0', ...
    'Units', 'normalized', 'Position', [0.54, y - alto, 0.42, alto], ...
    'BackgroundColor', 'white', 'FontSize', 9, ...
    'TooltipString', 'Impacto a descartar. 0 = ninguno. Escribe 2 si ese golpe salió con ruido.');
y = y - alto - 0.004;
[H.lblM, y] = uiTexto(panel, y, 'Modal: (no seleccionada). Descartar impacto →', 0.022);

[~, y] = uiTexto(panel, y, 'O escribe métricas si todavía no hay archivos', 0.024);
[~, y] = uiDosTextos(panel, y, 'RMS aceleración [g]', 'RMS fuerza [V]', 0.020);
[H.edRmsa, H.edRmsf, y] = uiDosEdits(panel, y, '', '', 0.032);
[~, y] = uiDosTextos(panel, y, 'Frecuencia natural [Hz]', 'Amplitud modal [g]', 0.020);
[H.edFnat, H.edAmp, y] = uiDosEdits(panel, y, '', '', 0.032);

H.chkChatter = uicontrol('Parent', panel, 'Style', 'checkbox', ...
    'String', 'Marcar chatter (solo si no hay archivos)', ...
    'Units', 'normalized', 'Position', [0.04, 0.055, 0.92, 0.028], ...
    'BackgroundColor', fondo, 'FontSize', 9, 'Value', 0);

H.btnAgregar = uicontrol('Parent', panel, 'Style', 'pushbutton', ...
    'String', 'Agregar prueba', ...
    'Units', 'normalized', 'Position', [0.04, 0.010, 0.92, 0.038], ...
    'FontSize', 11, 'FontWeight', 'bold', ...
    'BackgroundColor', [0.12 0.35 0.62], 'ForegroundColor', 'white', ...
    'Callback', @agregar);

H.carpetaA = '';
H.carpetaF = '';
H.carpetaM = '';

columnas = { ...
    'Nombre', 'Prof. (mm)', 'Refrigerante', 'Herramienta', 'Eje', ...
    'RMS a (g)', 'RMS F (V)', 'f natural (Hz)', 'Pico (Hz)', ...
    'Amp modal (g)', 'Chatter', 'Crecimiento', 'Índice'};

H.tabla = uitable( ...
    'Parent', fig, ...
    'Units', 'normalized', ...
    'Position', [0.292 0.62 0.698 0.365], ...
    'ColumnName', columnas, ...
    'ColumnWidth', {150, 70, 120, 90, 90, 75, 75, 90, 70, 90, 70, 85, 60}, ...
    'RowStriping', 'on', ...
    'FontSize', 9, ...
    'CellSelectionCallback', @alSeleccionar);

H.status = uicontrol('Parent', fig, 'Style', 'text', ...
    'String', 'Listo.', ...
    'Units', 'normalized', 'Position', [0.292 0.012 0.28 0.040], ...
    'HorizontalAlignment', 'left', 'BackgroundColor', fondo, 'FontSize', 9);

uicontrol('Parent', fig, 'Style', 'pushbutton', 'String', 'Eliminar', ...
    'Units', 'normalized', 'Position', [0.58 0.014 0.09 0.040], ...
    'Callback', @eliminar);
uicontrol('Parent', fig, 'Style', 'pushbutton', 'String', 'Guardar', ...
    'Units', 'normalized', 'Position', [0.68 0.014 0.09 0.040], ...
    'Callback', @guardar);
uicontrol('Parent', fig, 'Style', 'pushbutton', 'String', 'Cargar', ...
    'Units', 'normalized', 'Position', [0.78 0.014 0.09 0.040], ...
    'Callback', @cargar);
uicontrol('Parent', fig, 'Style', 'pushbutton', 'String', 'Exportar CSV', ...
    'Units', 'normalized', 'Position', [0.88 0.014 0.105 0.040], ...
    'Callback', @exportarCsv);

tabs = uitabgroup(fig, 'Units', 'normalized', 'Position', [0.292 0.065 0.698 0.545]);

tabComp = uitab(tabs, 'Title', 'Comparación');
H.axRmsA = crearEjes(tabComp, [0.08 0.58 0.40 0.36]);
H.axRmsF = crearEjes(tabComp, [0.57 0.58 0.40 0.36]);
H.axAmp = crearEjes(tabComp, [0.08 0.10 0.40 0.36]);
H.axInd = crearEjes(tabComp, [0.57 0.10 0.40 0.36]);

tabSen = uitab(tabs, 'Title', 'Señales');
H.axA = crearEjes(tabSen, [0.08 0.56 0.88 0.38]);
H.axF = crearEjes(tabSen, [0.08 0.12 0.88 0.36]);
H.lblSel = uicontrol('Parent', tabSen, 'Style', 'text', 'String', '', ...
    'Units', 'normalized', 'Position', [0.08 0.01 0.88 0.08], ...
    'HorizontalAlignment', 'left', 'BackgroundColor', get(tabSen, 'BackgroundColor'), ...
    'FontSize', 9);

tabFft = uitab(tabs, 'Title', 'Espectro');
H.axFft = crearEjes(tabFft, [0.08 0.12 0.88 0.80]);

tabMod = uitab(tabs, 'Title', 'Modal');
H.axMod = crearEjes(tabMod, [0.10 0.16 0.84 0.74]);

tabCon = uitab(tabs, 'Title', 'Viabilidad');
H.txtConclusion = uicontrol('Parent', tabCon, 'Style', 'edit', ...
    'Max', 2, 'Min', 0, 'Enable', 'inactive', ...
    'HorizontalAlignment', 'left', ...
    'FontName', 'Consolas', 'FontSize', 10, ...
    'Units', 'normalized', 'Position', [0.02 0.02 0.96 0.96], ...
    'BackgroundColor', 'white');

if exist(rutaCatalogo, 'file')
    try
        cargarRuta(rutaCatalogo, false);
        ponerEstado(['Catálogo cargado: ' rutaCatalogo]);
    catch ME
        ponerEstado(['No se pudo cargar el catálogo: ' ME.message]);
    end
end

refrescar();

    function alCambiarProf(~, ~)
        if strcmp(valorPopup(H.popProf), 'Otra')
            set(H.edOtra, 'Enable', 'on');
        else
            set(H.edOtra, 'Enable', 'off');
        end
    end

    function elegirA(~, ~)
        elegirCarpeta('carpetaA', H.lblA, 'Aceleración', 'Selecciona la carpeta de aceleración');
    end

    function elegirF(~, ~)
        elegirCarpeta('carpetaF', H.lblF, 'Fuerza', 'Selecciona la carpeta de fuerza');
    end

    function elegirM(~, ~)
        elegirCarpeta('carpetaM', H.lblM, 'Modal', 'Selecciona la carpeta del análisis modal');
    end

    function elegirCarpeta(campo, etiqueta, titulo, mensaje)
        inicio = pwd;
        if ~isempty(H.(campo))
            inicio = H.(campo);
        end
        carpeta = uigetdir(inicio, mensaje);
        if isequal(carpeta, 0)
            return
        end
        H.(campo) = carpeta;
        [~, nombre] = fileparts(carpeta);
        set(etiqueta, 'String', [titulo ': ' nombre], 'TooltipString', carpeta);
    end

    function agregar(~, ~)
        wb = [];
        try
            ap = leerProfundidad();
            if ~isfinite(ap) || ap <= 0
                errordlg('La profundidad debe ser un número mayor que cero.', 'Dato no válido');
                return
            end

            ref = valorPopup(H.popRef);
            herr = valorPopup(H.popHerr);
            eje = valorPopup(H.popEje);
            nombre = strtrim(get(H.edNombre, 'String'));
            if isempty(nombre)
                nombre = sprintf('%.4g mm | %s | %s', ap, ref, herr);
            end

            rmsMan = numeroOpcional(H.edRmsa);
            rmsFman = numeroOpcional(H.edRmsf);
            fMan = numeroOpcional(H.edFnat);
            aMan = numeroOpcional(H.edAmp);
            descartar = numeroOpcional(H.edDesc);
            if ~isfinite(descartar)
                descartar = 0;
            end
            descartar = round(descartar);

            if isempty(H.carpetaA) && isempty(H.carpetaF) && isempty(H.carpetaM) ...
                    && ~isfinite(rmsMan) && ~isfinite(rmsFman) ...
                    && ~isfinite(fMan) && ~isfinite(aMan)
                errordlg(['Selecciona al menos una carpeta o escribe una métrica.' newline ...
                    'Si los archivos están en ZIP, descomprímelos antes.'], 'Faltan datos');
                return
            end

            p = plantillaPrueba();
            p.nombre = nombre;
            p.profundidad = ap;
            p.refrigerante = ref;
            p.herramienta = herr;
            p.eje = eje;
            p.notas = strtrim(get(H.edNotas, 'String'));
            p.fecha = datestr(now, 'yyyy-mm-dd HH:MM');
            p.carpetaA = H.carpetaA;
            p.carpetaF = H.carpetaF;
            p.carpetaM = H.carpetaM;
            p.manual = true;

            if ~isempty(H.carpetaM)
                ponerEstado('Leyendo análisis modal...');
                wb = waitbar(0.2, 'Leyendo análisis modal...');
                [p.fNatural, nImp] = frecuenciaNatural(H.carpetaM, descartar);
                if isfinite(p.fNatural)
                    p.banda = [max(20, p.fNatural - 125), p.fNatural + 125];
                    p.notas = strtrim(sprintf('%s Modal: %d impactos útiles, %.1f Hz.', ...
                        p.notas, nImp, p.fNatural));
                else
                    warndlg(['No se estimó la frecuencia natural. ' ...
                        'La banda modal será 1300-1550 Hz.'], 'Análisis modal');
                end
            end

            if ~isfinite(p.fNatural) && isfinite(fMan) && fMan > 0
                p.fNatural = fMan;
                p.banda = [max(20, fMan - 125), fMan + 125];
            end

            if ~isempty(H.carpetaA)
                ponerEstado('Leyendo aceleración...');
                if isempty(wb)
                    wb = waitbar(0.45, 'Leyendo aceleración...');
                else
                    waitbar(0.5, wb, 'Leyendo aceleración...');
                end
                R = metricasAceleracion(H.carpetaA, p.banda);
                p.rmsA = R.rmsA;
                p.fsA = R.Fs;
                p.fModal = R.fModal;
                p.ampModal = R.ampModal;
                p.chatter = R.chatter;
                p.razonCrecimiento = R.razon;
                p.nA = R.n;
                p.tA = R.t;
                p.aA = R.a;
                p.fFFT = R.f;
                p.pFFT = R.P;
                p.manual = false;
                if numel(R.rmsCan) >= 3
                    p.rmsAx = R.rmsCan(1);
                    p.rmsAy = R.rmsCan(2);
                    p.rmsAz = R.rmsCan(3);
                    p.canalFFT = ejeCanal(R.canal);
                elseif numel(R.rmsCan) == 2
                    p.rmsAx = R.rmsCan(1);
                    p.rmsAy = R.rmsCan(2);
                    p.canalFFT = ejeCanal(R.canal);
                else
                    p.canalFFT = eje;
                    switch eje
                        case 'Y'
                            p.rmsAy = R.rmsCan(1);
                        case 'Z'
                            p.rmsAz = R.rmsCan(1);
                        otherwise
                            p.rmsAx = R.rmsCan(1);
                    end
                end
            else
                p.rmsA = rmsMan;
                p.ampModal = aMan;
                if isfinite(fMan)
                    p.fModal = fMan;
                end
                p.chatter = logical(get(H.chkChatter, 'Value'));
            end

            if ~isempty(H.carpetaF)
                ponerEstado('Leyendo fuerza...');
                if isempty(wb)
                    wb = waitbar(0.75, 'Leyendo fuerza...');
                else
                    waitbar(0.8, wb, 'Leyendo fuerza...');
                end
                Fz = metricasFuerza(H.carpetaF);
                p.rmsFx = Fz.rms(1);
                p.rmsFy = Fz.rms(2);
                p.rmsFz = Fz.rms(3);
                p.rmsF = Fz.rmsR;
                p.fsF = Fz.Fs;
                p.nF = Fz.n;
                p.tF = Fz.t;
                p.F = Fz.F;
                p.unidadF = 'V';
                p.manual = false;
            elseif ~isfinite(p.rmsF)
                p.rmsF = rmsFman;
            end

            if ~isempty(wb) && ishandle(wb)
                close(wb);
                wb = [];
            end

            if isempty(pruebas)
                pruebas = p;
            else
                pruebas(end + 1) = p; %#ok<AGROW>
            end
            pruebas = pruebas(:);
            filaSel = numel(pruebas);
            filasSel = filaSel;
            guardarSilencioso();
            refrescar();
            ponerEstado(['Prueba agregada y guardada: ' nombre]);
        catch ME
            if ~isempty(wb) && ishandle(wb)
                close(wb);
            end
            errordlg(ME.message, 'No se pudo agregar la prueba');
            ponerEstado('No se pudo agregar la prueba.');
        end
    end

    function ap = leerProfundidad()
        etiqueta = valorPopup(H.popProf);
        switch etiqueta
            case '0.5 mm'
                ap = 0.5;
            case '1 mm'
                ap = 1;
            case '2 mm'
                ap = 2;
            case '2.5 mm'
                ap = 2.5;
            case '3 mm'
                ap = 3;
            otherwise
                ap = str2double(strtrim(get(H.edOtra, 'String')));
        end
    end

    function eliminar(~, ~)
        if isempty(pruebas) || isempty(filasSel)
            errordlg('Selecciona una fila de la tabla.', 'Sin selección');
            return
        end
        resp = questdlg('¿Eliminar la prueba seleccionada?', ...
            'Confirmar', 'Eliminar', 'Cancelar', 'Cancelar');
        if ~strcmp(resp, 'Eliminar')
            return
        end
        pruebas(filasSel) = [];
        if isempty(pruebas)
            filaSel = [];
            filasSel = [];
        else
            filaSel = min(filasSel(1), numel(pruebas));
            filasSel = filaSel;
        end
        guardarSilencioso();
        refrescar();
        ponerEstado('Prueba eliminada.');
    end

    function alSeleccionar(~, evento)
        if isempty(evento.Indices)
            return
        end
        filasSel = unique(evento.Indices(:, 1));
        filaSel = filasSel(1);
        graficarSenales();
        graficarEspectro();
    end

    function guardar(~, ~)
        try
            guardarSilencioso();
            msgbox(sprintf('Catálogo guardado en:\n%s', rutaCatalogo), 'Guardado');
            ponerEstado(['Guardado: ' rutaCatalogo]);
        catch ME
            errordlg(ME.message, 'No se pudo guardar');
        end
    end

    function guardarComo(~, ~)
        [archivo, carpeta] = uiputfile('catalogo_chatter.mat', 'Guardar catálogo');
        if isequal(archivo, 0)
            return
        end
        rutaCatalogo = fullfile(carpeta, archivo);
        guardar();
    end

    function guardarSilencioso()
        catalogo = pruebas; %#ok<NASGU>
        versionCatalogo = 1; %#ok<NASGU>
        save(rutaCatalogo, 'catalogo', 'versionCatalogo');
    end

    function cargar(~, ~)
        if ~isempty(pruebas)
            resp = questdlg('Esto sustituye las pruebas que están en memoria.', ...
                'Cargar', 'Continuar', 'Cancelar', 'Cancelar');
            if ~strcmp(resp, 'Continuar')
                return
            end
        end
        [archivo, carpeta] = uigetfile('*.mat', 'Cargar catálogo');
        if isequal(archivo, 0)
            return
        end
        try
            cargarRuta(fullfile(carpeta, archivo), true);
            rutaCatalogo = fullfile(carpeta, archivo);
            refrescar();
            ponerEstado(['Catálogo cargado: ' rutaCatalogo]);
        catch ME
            errordlg(ME.message, 'No se pudo cargar');
        end
    end

    function cargarRuta(ruta, ~)
        S = load(ruta);
        if ~isfield(S, 'catalogo')
            error('El archivo no contiene la variable catalogo.');
        end
        pruebas = completarArreglo(S.catalogo);
        if isempty(pruebas)
            filaSel = [];
            filasSel = [];
        else
            pruebas = pruebas(:);
            filaSel = 1;
            filasSel = 1;
        end
    end

    function exportarCsv(~, ~)
        if isempty(pruebas)
            errordlg('No hay pruebas para exportar.', 'Exportar');
            return
        end
        [archivo, carpeta] = uiputfile('resumen_chatter.csv', 'Exportar resumen');
        if isequal(archivo, 0)
            return
        end
        ruta = fullfile(carpeta, archivo);
        fid = fopen(ruta, 'w');
        if fid < 0
            errordlg('No se pudo crear el archivo CSV.', 'Exportar');
            return
        end
        limpiar = onCleanup(@() fclose(fid));
        fprintf(fid, ['nombre,fecha,profundidad_mm,refrigerante,herramienta,eje,' ...
            'rms_a_g,rms_ax,rms_ay,rms_az,rms_fx,rms_fy,rms_fz,rms_f,' ...
            'f_natural_Hz,pico_Hz,amp_modal_g,chatter,crecimiento,indice,notas\n']);
        for i = 1:numel(pruebas)
            p = pruebas(i);
            fprintf(fid, '%s,%s,%.8g,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%d,%s,%s,%s\n', ...
                csvTexto(p.nombre), csvTexto(p.fecha), p.profundidad, ...
                csvTexto(p.refrigerante), csvTexto(p.herramienta), csvTexto(p.eje), ...
                csvNum(p.rmsA), csvNum(p.rmsAx), csvNum(p.rmsAy), csvNum(p.rmsAz), ...
                csvNum(p.rmsFx), csvNum(p.rmsFy), csvNum(p.rmsFz), csvNum(p.rmsF), ...
                csvNum(p.fNatural), csvNum(p.fModal), csvNum(p.ampModal), ...
                logical(p.chatter), csvNum(p.razonCrecimiento), csvNum(p.indice), ...
                csvTexto(p.notas));
        end
        clear limpiar
        ponerEstado(['CSV exportado: ' ruta]);
    end

    function crearCarpetas(~, ~)
        raiz = uigetdir(pwd, 'Elige dónde crear las carpetas de las pruebas');
        if isequal(raiz, 0)
            return
        end
        condiciones = { ...
            'Sin refrigerante - Nueva', ...
            'Sin refrigerante - Desgastada', ...
            'Con refrigerante - Nueva', ...
            'Con refrigerante - Desgastada'};
        profundidades = {'0.5 mm', '1 mm', '2 mm', '2.5 mm', '3 mm'};
        tipos = {'Aceleracion', 'Fuerza', 'Modal'};
        for i = 1:numel(condiciones)
            for j = 1:numel(profundidades)
                for k = 1:numel(tipos)
                    mkdir(fullfile(raiz, condiciones{i}, profundidades{j}, tipos{k}));
                end
            end
        end
        msgbox(sprintf(['Carpetas creadas en:\n%s\n\n' ...
            'Coloca los A*.lvm en Aceleracion, los F*.lvm en Fuerza\n' ...
            'y los impactos modales en Modal. Si están en ZIP, descomprímelos.'], raiz), ...
            'Carpetas listas');
    end

    function refrescar()
        if ~isempty(pruebas)
            pruebas = pruebas(:);
            pruebas = calcularIndices(pruebas);
        end
        actualizarTabla();
        graficarComparacion();
        graficarSenales();
        graficarEspectro();
        graficarModal();
        set(H.txtConclusion, 'String', redactarConclusion(pruebas));
        drawnow
    end

    function actualizarTabla()
        if isempty(pruebas)
            set(H.tabla, 'Data', cell(0, 13));
            return
        end
        datos = cell(numel(pruebas), 13);
        for i = 1:numel(pruebas)
            p = pruebas(i);
            if p.chatter
                txtCh = 'Sí';
            else
                txtCh = 'No';
            end
            datos(i, :) = { ...
                p.nombre, p.profundidad, p.refrigerante, p.herramienta, p.eje, ...
                fmt(p.rmsA, '%.4f'), fmt(p.rmsF, '%.4f'), ...
                fmt(p.fNatural, '%.1f'), fmt(p.fModal, '%.1f'), ...
                fmt(p.ampModal, '%.5f'), txtCh, ...
                fmt(p.razonCrecimiento, '%.2f'), fmt(p.indice, '%.3f')};
        end
        set(H.tabla, 'Data', datos);
    end

    function graficarComparacion()
        graficarMetrica(H.axRmsA, 'rmsA', 'RMS [g]', 'Vibración durante el corte');
        graficarMetrica(H.axRmsF, 'rmsF', 'RMS [V]', 'Fuerza resultante');
        graficarMetrica(H.axAmp, 'ampModal', 'Amplitud [g]', 'Pico en la banda modal');
        graficarMetrica(H.axInd, 'indice', 'Índice (menor = mejor)', 'Severidad dinámica');
    end

    function graficarMetrica(ax, campo, ylab, titulo)
        cla(ax);
        if isempty(pruebas)
            mostrarVacio(ax, 'Agrega pruebas para comparar.');
            return
        end
        axis(ax, 'on');
        hold(ax, 'on');
        claves = celdaCampo(pruebas, 'clave');
        unicas = unique(claves, 'stable');
        hay = false;
        for k = 1:numel(unicas)
            mask = strcmp(claves, unicas{k});
            sub = pruebas(mask);
            [x, yv, e] = promedioCampo(sub, campo);
            if isempty(x)
                continue
            end
            partes = strsplit(unicas{k}, ' | ');
            color = colorCondicion(partes{1}, partes{2});
            errorbar(ax, x, yv, e, '-o', ...
                'Color', color, ...
                'MarkerFaceColor', color, ...
                'LineWidth', 1.5, ...
                'MarkerSize', 7, ...
                'DisplayName', unicas{k});
            hay = true;
        end
        if ~hay
            mostrarVacio(ax, 'No hay valores para esta gráfica.');
            return
        end
        grid(ax, 'on');
        box(ax, 'on');
        xlabel(ax, 'Profundidad de corte [mm]', 'Interpreter', 'none');
        ylabel(ax, ylab, 'Interpreter', 'none');
        title(ax, titulo, 'Interpreter', 'none');
        lg = legend(ax, 'Location', 'best');
        set(lg, 'Interpreter', 'none', 'FontSize', 8);
        hold(ax, 'off');
        profs = columnaCampo(pruebas, 'profundidad');
        xlim(ax, [min([0.25; profs - 0.15]), max([3.25; profs + 0.15])]);
        ticks = unique([0.5; 1; 2; 2.5; 3; profs]);
        set(ax, 'XTick', ticks);
    end

    function graficarSenales()
        cla(H.axA);
        cla(H.axF);
        if isempty(pruebas) || isempty(filaSel) || filaSel < 1 || filaSel > numel(pruebas)
            mostrarVacio(H.axA, 'Selecciona una prueba de la tabla.');
            mostrarVacio(H.axF, 'Selecciona una prueba de la tabla.');
            set(H.lblSel, 'String', '');
            return
        end
        p = pruebas(filaSel);
        set(H.lblSel, 'String', sprintf('%s  |  %s  |  eje %s  |  %s', ...
            p.fecha, p.nombre, p.eje, p.notas));

        if isempty(p.tA)
            mostrarVacio(H.axA, 'Esta prueba no tiene señal de aceleración.');
        else
            axis(H.axA, 'on');
            hold(H.axA, 'on');
            colores = [0.15 0.35 0.75; 0.80 0.25 0.20; 0.10 0.55 0.30];
            nombres = {'X', 'Y', 'Z'};
            nCan = size(p.aA, 2);
            if nCan == 1
                plot(H.axA, p.tA, p.aA(:, 1), 'Color', colores(1, :), 'LineWidth', 0.8);
                legend(H.axA, ['Aceleración ' p.eje], 'Location', 'best', 'Interpreter', 'none');
            else
                for c = 1:min(nCan, 3)
                    plot(H.axA, p.tA, p.aA(:, c), ...
                        'Color', colores(c, :), 'LineWidth', 0.8, ...
                        'DisplayName', nombres{c});
                end
                lg = legend(H.axA, 'Location', 'best');
                set(lg, 'Interpreter', 'none');
            end
            hold(H.axA, 'off');
            grid(H.axA, 'on');
            box(H.axA, 'on');
            xlabel(H.axA, 'Tiempo [s]');
            ylabel(H.axA, 'Aceleración tarada [g]');
            titulo = sprintf('%s | RMS = %s g', p.nombre, fmt(p.rmsA, '%.4f'));
            if isfinite(p.razonCrecimiento)
                titulo = sprintf('%s | fin/inicio = %.2f', titulo, p.razonCrecimiento);
            end
            title(H.axA, titulo, 'Interpreter', 'none');
        end

        if isempty(p.tF)
            mostrarVacio(H.axF, 'Esta prueba no tiene señal de fuerza.');
        else
            axis(H.axF, 'on');
            hold(H.axF, 'on');
            coloresF = [0.15 0.35 0.75; 0.80 0.25 0.20; 0.10 0.55 0.30];
            nombresF = {'F_x', 'F_y', 'F_z'};
            for c = 1:min(3, size(p.F, 2))
                plot(H.axF, p.tF, p.F(:, c), ...
                    'Color', coloresF(c, :), 'LineWidth', 0.8, ...
                    'DisplayName', nombresF{c});
            end
            hold(H.axF, 'off');
            grid(H.axF, 'on');
            box(H.axF, 'on');
            xlabel(H.axF, 'Tiempo [s]');
            ylabel(H.axF, 'Fuerza tarada [V]');
            title(H.axF, sprintf('%s | RMS resultante = %s V', p.nombre, fmt(p.rmsF, '%.4f')), ...
                'Interpreter', 'none');
            lg = legend(H.axF, 'Location', 'best');
            set(lg, 'Interpreter', 'tex');
        end

        if ~isempty(p.tA) && ~isempty(p.tF)
            rango = [min(p.tA(1), p.tF(1)), max(p.tA(end), p.tF(end))];
            if rango(2) > rango(1)
                xlim(H.axA, rango);
                xlim(H.axF, rango);
            end
        end
    end

    function graficarEspectro()
        cla(H.axFft);
        if isempty(pruebas) || isempty(filaSel) || filaSel < 1 || filaSel > numel(pruebas)
            mostrarVacio(H.axFft, 'Selecciona una prueba para ver su espectro.');
            return
        end
        p = pruebas(filaSel);
        if isempty(p.fFFT)
            mostrarVacio(H.axFft, 'Esta prueba no tiene espectro de aceleración.');
            return
        end
        axis(H.axFft, 'on');
        plot(H.axFft, p.fFFT, p.pFFT, 'Color', [0.15 0.35 0.75], 'LineWidth', 1);
        hold(H.axFft, 'on');
        if numel(p.banda) == 2 && all(isfinite(p.banda))
            yl = ylim(H.axFft);
            line(H.axFft, [p.banda(1) p.banda(1)], yl, ...
                'Color', [0.75 0.15 0.15], 'LineStyle', '--', 'LineWidth', 1);
            line(H.axFft, [p.banda(2) p.banda(2)], yl, ...
                'Color', [0.75 0.15 0.15], 'LineStyle', '--', 'LineWidth', 1);
            ylim(H.axFft, yl);
        end
        if isfinite(p.fModal) && isfinite(p.ampModal)
            plot(H.axFft, p.fModal, p.ampModal, 'o', ...
                'MarkerFaceColor', [0.85 0.2 0.2], 'MarkerEdgeColor', [0.85 0.2 0.2]);
        end
        hold(H.axFft, 'off');
        grid(H.axFft, 'on');
        box(H.axFft, 'on');
        xlabel(H.axFft, 'Frecuencia [Hz]');
        ylabel(H.axFft, 'Amplitud [g]');
        if p.chatter
            estado = 'indicador de chatter: sí';
        else
            estado = 'indicador de chatter: no';
        end
        title(H.axFft, sprintf('%s | canal %s | pico %s Hz | %s', ...
            p.nombre, p.canalFFT, fmt(p.fModal, '%.1f'), estado), ...
            'Interpreter', 'none');
        if ~isempty(p.fFFT)
            xlim(H.axFft, [0, min(4000, max(p.fFFT))]);
        end
    end

    function graficarModal()
        cla(H.axMod);
        if isempty(pruebas)
            mostrarVacio(H.axMod, 'Agrega un análisis modal para ver la frecuencia natural.');
            return
        end
        vals = [];
        etiquetas = {};
        for i = 1:numel(pruebas)
            if isfinite(pruebas(i).fNatural)
                vals(end + 1) = pruebas(i).fNatural; %#ok<AGROW>
                etiquetas{end + 1} = sprintf('%.4g mm | %s', ...
                    pruebas(i).profundidad, pruebas(i).herramienta); %#ok<AGROW>
            end
        end
        if isempty(vals)
            mostrarVacio(H.axMod, 'Ninguna prueba tiene frecuencia natural.');
            return
        end
        axis(H.axMod, 'on');
        bar(H.axMod, vals, 'FaceColor', [0.20 0.45 0.70]);
        grid(H.axMod, 'on');
        box(H.axMod, 'on');
        ylabel(H.axMod, 'Frecuencia natural [Hz]');
        title(H.axMod, 'Modo de la herramienta identificado por impactos', 'Interpreter', 'none');
        set(H.axMod, 'XTick', 1:numel(vals), 'XTickLabel', etiquetas, 'XTickLabelRotation', 25);
        xlim(H.axMod, [0.4, numel(vals) + 0.6]);
    end

    function ponerEstado(texto)
        set(H.status, 'String', texto);
        drawnow
    end

end

function [h, y] = uiTexto(parent, y, txt, alto)
fondo = get(parent, 'BackgroundColor');
h = uicontrol('Parent', parent, 'Style', 'text', 'String', txt, ...
    'Units', 'normalized', 'Position', [0.04, y - alto, 0.92, alto], ...
    'HorizontalAlignment', 'left', 'BackgroundColor', fondo, 'FontSize', 9);
y = y - alto - 0.004;
end

function [h1, h2, y] = uiDosTextos(parent, y, t1, t2, alto)
fondo = get(parent, 'BackgroundColor');
h1 = uicontrol('Parent', parent, 'Style', 'text', 'String', t1, ...
    'Units', 'normalized', 'Position', [0.04, y - alto, 0.44, alto], ...
    'HorizontalAlignment', 'left', 'BackgroundColor', fondo, 'FontSize', 8);
h2 = uicontrol('Parent', parent, 'Style', 'text', 'String', t2, ...
    'Units', 'normalized', 'Position', [0.52, y - alto, 0.44, alto], ...
    'HorizontalAlignment', 'left', 'BackgroundColor', fondo, 'FontSize', 8);
y = y - alto - 0.002;
end

function [h, y] = uiEdit(parent, y, cadena, alto)
h = uicontrol('Parent', parent, 'Style', 'edit', 'String', cadena, ...
    'Units', 'normalized', 'Position', [0.04, y - alto, 0.92, alto], ...
    'HorizontalAlignment', 'left', 'BackgroundColor', 'white', 'FontSize', 9);
y = y - alto - 0.008;
end

function [h1, h2, y] = uiDosEdits(parent, y, s1, s2, alto)
h1 = uicontrol('Parent', parent, 'Style', 'edit', 'String', s1, ...
    'Units', 'normalized', 'Position', [0.04, y - alto, 0.44, alto], ...
    'BackgroundColor', 'white', 'FontSize', 9);
h2 = uicontrol('Parent', parent, 'Style', 'edit', 'String', s2, ...
    'Units', 'normalized', 'Position', [0.52, y - alto, 0.44, alto], ...
    'BackgroundColor', 'white', 'FontSize', 9);
y = y - alto - 0.006;
end

function [h, y] = uiPopup(parent, y, items, alto)
h = uicontrol('Parent', parent, 'Style', 'popupmenu', 'String', items, ...
    'Units', 'normalized', 'Position', [0.04, y - alto, 0.92, alto], ...
    'BackgroundColor', 'white', 'FontSize', 9);
y = y - alto - 0.008;
end

function [h, y] = uiBoton(parent, y, txt, alto, cb)
h = uicontrol('Parent', parent, 'Style', 'pushbutton', 'String', txt, ...
    'Units', 'normalized', 'Position', [0.04, y - alto, 0.92, alto], ...
    'FontSize', 9, 'Callback', cb);
y = y - alto - 0.004;
end

function ax = crearEjes(parent, pos)
ax = axes('Parent', parent, 'Units', 'normalized', 'Position', pos, 'FontSize', 9);
set(ax, 'TickLabelInterpreter', 'none');
end

function p = plantillaPrueba()
p.nombre = '';
p.profundidad = NaN;
p.refrigerante = '';
p.herramienta = '';
p.eje = '';
p.notas = '';
p.fecha = '';
p.carpetaA = '';
p.carpetaF = '';
p.carpetaM = '';
p.manual = false;
p.rmsA = NaN;
p.rmsAx = NaN;
p.rmsAy = NaN;
p.rmsAz = NaN;
p.fsA = NaN;
p.rmsFx = NaN;
p.rmsFy = NaN;
p.rmsFz = NaN;
p.rmsF = NaN;
p.fsF = NaN;
p.unidadF = 'V';
p.fNatural = NaN;
p.fModal = NaN;
p.ampModal = NaN;
p.banda = [1300 1550];
p.chatter = false;
p.razonCrecimiento = NaN;
p.indice = NaN;
p.nA = 0;
p.nF = 0;
p.tA = [];
p.aA = [];
p.canalFFT = '';
p.tF = [];
p.F = [];
p.fFFT = [];
p.pFFT = [];
end

function arr = completarArreglo(arr)
if isempty(arr)
    arr = repmat(plantillaPrueba(), 0, 1);
    return
end
n = numel(arr);
base = repmat(plantillaPrueba(), n, 1);
for i = 1:n
    base(i) = completarUno(arr(i));
end
arr = base;
end

function p2 = completarUno(p)
p2 = plantillaPrueba();
campos = fieldnames(p2);
for i = 1:numel(campos)
    if isfield(p, campos{i}) && ~isempty(p.(campos{i}))
        p2.(campos{i}) = p.(campos{i});
    end
end
p2.chatter = logical(p2.chatter);
end

function pruebas = calcularIndices(pruebas)
n = numel(pruebas);
rmsA = nan(n, 1);
amp = nan(n, 1);
rmsF = nan(n, 1);
for i = 1:n
    rmsA(i) = pruebas(i).rmsA;
    amp(i) = pruebas(i).ampModal;
    rmsF(i) = pruebas(i).rmsF;
end
refA = maxFin(rmsA);
refP = maxFin(amp);
refF = maxFin(rmsF);
for i = 1:n
    partes = [];
    pesos = [];
    if isfinite(rmsA(i)) && isfinite(refA) && refA > 0
        partes(end + 1) = rmsA(i) / refA; %#ok<AGROW>
        pesos(end + 1) = 0.45; %#ok<AGROW>
    end
    if isfinite(amp(i)) && isfinite(refP) && refP > 0
        partes(end + 1) = amp(i) / refP; %#ok<AGROW>
        pesos(end + 1) = 0.35; %#ok<AGROW>
    end
    if isfinite(rmsF(i)) && isfinite(refF) && refF > 0
        partes(end + 1) = rmsF(i) / refF; %#ok<AGROW>
        pesos(end + 1) = 0.20; %#ok<AGROW>
    end
    if isempty(partes)
        pruebas(i).indice = NaN;
    else
        pruebas(i).indice = sum(partes .* pesos) / sum(pesos);
        if pruebas(i).chatter
            pruebas(i).indice = pruebas(i).indice + 0.15;
        end
    end
end
end

function m = maxFin(v)
v = v(isfinite(v));
if isempty(v)
    m = NaN;
else
    m = max(v);
end
end

function [x, y, e] = promedioCampo(sub, campo)
x = [];
y = [];
e = [];
sub = sub(:);
if isempty(sub)
    return
end
profs = unique(columnaCampo(sub, 'profundidad'));
profs = sort(profs);
for i = 1:numel(profs)
    mask = abs(columnaCampo(sub, 'profundidad') - profs(i)) < 1e-9;
    vals = columnaCampo(sub(mask), campo);
    vals = vals(isfinite(vals));
    if isempty(vals)
        continue
    end
    x(end + 1) = profs(i); %#ok<AGROW>
    y(end + 1) = mean(vals); %#ok<AGROW>
    if numel(vals) > 1
        e(end + 1) = std(vals); %#ok<AGROW>
    else
        e(end + 1) = 0; %#ok<AGROW>
    end
end
end

function v = columnaCampo(arr, campo)
n = numel(arr);
v = nan(n, 1);
for i = 1:n
    valor = arr(i).(campo);
    if isnumeric(valor) && isscalar(valor)
        v(i) = valor;
    end
end
end

function c = celdaCampo(arr, campo)
n = numel(arr);
c = cell(n, 1);
for i = 1:n
    if strcmp(campo, 'clave')
        c{i} = sprintf('%s | %s', arr(i).refrigerante, arr(i).herramienta);
    else
        c{i} = arr(i).(campo);
    end
end
end

function color = colorCondicion(ref, herr)
if strcmp(ref, 'Sin refrigerante') && strcmp(herr, 'Nueva')
    color = [0.20 0.40 0.80];
elseif strcmp(ref, 'Sin refrigerante')
    color = [0.82 0.22 0.18];
elseif strcmp(herr, 'Nueva')
    color = [0.12 0.58 0.30];
else
    color = [0.93 0.52 0.12];
end
end

function txt = valorPopup(h)
items = get(h, 'String');
txt = items{get(h, 'Value')};
end

function v = numeroOpcional(h)
s = strtrim(get(h, 'String'));
if isempty(s)
    v = NaN;
    return
end
v = str2double(s);
if ~isfinite(v)
    error('Valor numérico no válido: %s', s);
end
end

function s = fmt(v, spec)
if ~isfinite(v)
    s = '-';
else
    s = sprintf(spec, v);
end
end

function s = csvNum(v)
if ~isfinite(v)
    s = '';
else
    s = sprintf('%.8g', v);
end
end

function s = csvTexto(v)
if isempty(v)
    s = '""';
    return
end
v = strrep(char(v), '"', '""');
v = strrep(v, sprintf('\n'), ' ');
s = ['"' v '"'];
end

function nombre = ejeCanal(c)
nombres = {'X', 'Y', 'Z'};
if c >= 1 && c <= 3
    nombre = nombres{c};
else
    nombre = sprintf('Canal %d', c);
end
end

function mostrarVacio(ax, msg)
cla(ax);
axis(ax, 'off');
xlim(ax, [0 1]);
ylim(ax, [0 1]);
text(ax, 0.5, 0.5, msg, ...
    'HorizontalAlignment', 'center', ...
    'FontSize', 10, ...
    'Color', [0.35 0.35 0.35], ...
    'Interpreter', 'none');
end

function txt = redactarConclusion(pruebas)
if isempty(pruebas)
    txt = strjoin({ ...
        'Aún no hay pruebas en el análisis.', ...
        '', ...
        'Cómo usarlo:', ...
        '1. Elige profundidad, refrigerante y estado de la herramienta.', ...
        '2. Selecciona las carpetas con archivos .lvm, o escribe RMS y frecuencias a mano.', ...
        '3. Pulsa Agregar prueba.', ...
        '4. Repite para 0.5, 1, 2, 2.5 y 3 mm, con y sin refrigerante, herramienta nueva y desgastada.', ...
        '', ...
        'El índice de severidad reúne la vibración (45%), el pico en la banda del modo de la herramienta (35%) y la fuerza (20%).', ...
        'Si el espectro marca chatter, el índice sube 0.15.', ...
        'Un índice más bajo es más favorable para que la herramienta dure más.', ...
        'Este índice no mide el desgaste de forma directa: resume la severidad dinámica del corte.'}, sprintf('\n'));
    return
end

pruebas = pruebas(:);
lineas = {};
lineas{end + 1} = 'VIABILIDAD DE LA HERRAMIENTA';
lineas{end + 1} = 'Un índice más bajo indica menos vibración, menos pico modal y menos fuerza.';
lineas{end + 1} = 'Es la condición más favorable para conservar el filo. No sustituye una medición directa de desgaste.';
lineas{end + 1} = '';

if numel(pruebas) < 2
    lineas{end + 1} = 'Con una sola prueba el índice queda cerca de 1, porque se normaliza con los datos cargados.';
    lineas{end + 1} = 'La comparación tiene sentido cuando hay al menos dos condiciones.';
    lineas{end + 1} = '';
end

profs = unique(columnaCampo(pruebas, 'profundidad'));
profs = sort(profs);
for d = 1:numel(profs)
    sub = pruebas(abs(columnaCampo(pruebas, 'profundidad') - profs(d)) < 1e-9);
    [nombres, medias, cuentas, chatterSi] = resumirCondiciones(sub);
    lineas{end + 1} = sprintf('Profundidad %.4g mm', profs(d)); %#ok<AGROW>
    if isempty(nombres)
        lineas{end + 1} = '  No hay índice calculable en esta profundidad.'; %#ok<AGROW>
        lineas{end + 1} = ''; %#ok<AGROW>
        continue
    end
    for k = 1:numel(nombres)
        if chatterSi(k)
            marca = 'con chatter';
        else
            marca = 'sin chatter marcado';
        end
        lineas{end + 1} = sprintf('  %s: índice %.3f (%d, %s)', ...
            nombres{k}, medias(k), cuentas(k), marca); %#ok<AGROW>
    end
    [mejor, iMejor] = min(medias);
    [peor, iPeor] = max(medias);
    if numel(nombres) == 1
        lineas{end + 1} = sprintf('  Solo está registrada: %s.', nombres{1}); %#ok<AGROW>
    elseif abs(mejor - peor) <= 0.05
        lineas{end + 1} = '  Las condiciones registradas quedan parecidas en esta profundidad.'; %#ok<AGROW>
    else
        lineas{end + 1} = sprintf('  Más favorable: %s (índice %.3f).', nombres{iMejor}, mejor); %#ok<AGROW>
        lineas{end + 1} = sprintf('  Menos favorable: %s (índice %.3f).', nombres{iPeor}, peor); %#ok<AGROW>
        if chatterSi(iMejor)
            lineas{end + 1} = '  La opción de menor índice aun así marcó chatter. Conviene repetir la pasada o bajar la profundidad.'; %#ok<AGROW>
        end
    end
    lineas{end + 1} = ''; %#ok<AGROW>
end

[dRef, nRef] = compararPareado(pruebas, 'refrigerante', 'Sin refrigerante', 'Con refrigerante');
lineas{end + 1} = 'Refrigerante, a la misma profundidad';
if nRef == 0
    lineas{end + 1} = '  Falta la misma profundidad con y sin refrigerante, así que todavía no se aísla ese efecto.';
elseif dRef < -0.05
    lineas{end + 1} = sprintf('  Con refrigerante el índice baja %.3f en promedio (%d profundidades). Se ve más favorable para la duración de la herramienta.', -dRef, nRef);
elseif dRef > 0.05
    lineas{end + 1} = sprintf('  Sin refrigerante el índice es menor por %.3f en promedio (%d profundidades). En estos datos el corte en seco se ve más estable.', dRef, nRef);
else
    lineas{end + 1} = sprintf('  La diferencia entre con y sin refrigerante es pequeña (%.3f, %d profundidades).', dRef, nRef);
end
lineas{end + 1} = '';

[dHer, nHer] = compararPareado(pruebas, 'herramienta', 'Nueva', 'Desgastada');
lineas{end + 1} = 'Estado de la herramienta, a la misma profundidad';
if nHer == 0
    lineas{end + 1} = '  Falta la misma profundidad con herramienta nueva y desgastada.';
elseif dHer > 0.05
    lineas{end + 1} = sprintf('  La herramienta desgastada sube el índice %.3f en promedio (%d profundidades). La herramienta nueva es más favorable.', dHer, nHer);
elseif dHer < -0.05
    lineas{end + 1} = sprintf('  La herramienta desgastada tiene un índice menor por %.3f (%d profundidades). Revisa el montaje y repite la prueba antes de concluir.', -dHer, nHer);
else
    lineas{end + 1} = sprintf('  Nueva y desgastada quedan parecidas (diferencia %.3f, %d profundidades).', dHer, nHer);
end
lineas{end + 1} = '';

for i = 1:numel(pruebas)
    if isfinite(pruebas(i).razonCrecimiento) && pruebas(i).razonCrecimiento >= 1.3
        lineas{end + 1} = sprintf('En "%s" la vibración al final de la pasada fue %.2f veces la del inicio. El corte se puso más severo durante la prueba.', ...
            pruebas(i).nombre, pruebas(i).razonCrecimiento); %#ok<AGROW>
    end
end

fNat = columnaCampo(pruebas, 'fNatural');
fNat = fNat(isfinite(fNat));
if ~isempty(fNat)
    if numel(fNat) > 1
        desvNat = std(fNat);
    else
        desvNat = 0;
    end
    lineas{end + 1} = '';
    lineas{end + 1} = sprintf('Frecuencia natural media de la herramienta: %.1f Hz (desviación %.1f Hz, %d registros).', ...
        mean(fNat), desvNat, numel(fNat));
    lineas{end + 1} = 'La banda de chatter se toma a ±125 Hz de esa frecuencia. Si no hay modal, se usa 1300-1550 Hz.';
end

plan = [0.5 1 2 2.5 3];
faltan = [];
for v = plan
    if ~any(abs(columnaCampo(pruebas, 'profundidad') - v) < 1e-6)
        faltan(end + 1) = v; %#ok<AGROW>
    end
end
lineas{end + 1} = '';
if isempty(faltan)
    lineas{end + 1} = 'Ya hay al menos una prueba en 0.5, 1, 2, 2.5 y 3 mm.';
else
    textoF = strjoin(arrayfun(@(v) sprintf('%.4g mm', v), faltan, 'UniformOutput', false), ', ');
    lineas{end + 1} = ['Profundidades del plan que todavía no están: ' textoF '.'];
end

lineas{end + 1} = '';
lineas{end + 1} = 'Criterio de chatter: el pico dentro de la banda modal supera 4 veces la mediana del resto del espectro entre 100 y 3000 Hz.';
lineas{end + 1} = 'Crecimiento: RMS del último tercio de la pasada dividido entre el RMS del primer tercio. Por encima de 1.3 la vibración aumentó durante el corte.';
txt = strjoin(lineas, sprintf('\n'));
end

function [nombres, medias, cuentas, chatterSi] = resumirCondiciones(sub)
sub = sub(:);
nombres = {};
medias = [];
cuentas = [];
chatterSi = [];
if isempty(sub)
    return
end
claves = celdaCampo(sub, 'clave');
unicas = unique(claves, 'stable');
for k = 1:numel(unicas)
    mask = strcmp(claves, unicas{k});
    ind = columnaCampo(sub(mask), 'indice');
    ind = ind(isfinite(ind));
    if isempty(ind)
        continue
    end
    nombres{end + 1} = unicas{k}; %#ok<AGROW>
    medias(end + 1) = mean(ind); %#ok<AGROW>
    cuentas(end + 1) = numel(ind); %#ok<AGROW>
    ch = false(numel(sub), 1);
    idx = find(mask);
    for j = 1:numel(idx)
        ch(idx(j)) = logical(sub(idx(j)).chatter);
    end
    chatterSi(end + 1) = any(ch(mask)); %#ok<AGROW>
end
end

function [deltaMed, nPares] = compararPareado(pruebas, campo, valA, valB)
profs = unique(columnaCampo(pruebas, 'profundidad'));
deltas = [];
for i = 1:numel(profs)
    sub = pruebas(abs(columnaCampo(pruebas, 'profundidad') - profs(i)) < 1e-9);
    mA = mediaWhere(sub, campo, valA);
    mB = mediaWhere(sub, campo, valB);
    if isfinite(mA) && isfinite(mB)
        deltas(end + 1) = mB - mA; %#ok<AGROW>
    end
end
if isempty(deltas)
    deltaMed = NaN;
    nPares = 0;
else
    deltaMed = mean(deltas);
    nPares = numel(deltas);
end
end

function m = mediaWhere(sub, campo, valor)
mask = false(numel(sub), 1);
for i = 1:numel(sub)
    mask(i) = strcmp(sub(i).(campo), valor);
end
if ~any(mask)
    m = NaN;
    return
end
ind = columnaCampo(sub(mask), 'indice');
ind = ind(isfinite(ind));
if isempty(ind)
    m = NaN;
else
    m = mean(ind);
end
end

function [fNat, nUsados] = frecuenciaNatural(carpeta, descartar)
[Y, Fs] = concatenarLVM(carpeta, 'A');
if isempty(Y)
    fNat = NaN;
    nUsados = 0;
    return
end
desv = std(Y, 0, 1);
[~, canal] = max(desv);
A = Y(:, canal);
A = A - mean(A);
Fs = Fs(1);
radio = max(1, round(0.005 * Fs));
distMin = round(0.03 * Fs);
env = movmean(abs(A), max(1, round(0.005 * Fs)));
locs = buscarPicos(env, 0.15, radio, distMin, 6);
if isempty(locs)
    locs = buscarPicos(env, 0.08, radio, distMin, 6);
end
if isempty(locs)
    fNat = NaN;
    nUsados = 0;
    return
end
if descartar >= 1 && descartar <= numel(locs)
    locs(descartar) = [];
end
if isempty(locs)
    fNat = NaN;
    nUsados = 0;
    return
end

muestrasPre = round(0.02 * Fs);
muestrasTot = round(1.0 * Fs);
frecs = [];
for i = 1:numel(locs)
    ini = max(1, locs(i) - muestrasPre);
    fin = min(numel(A), ini + muestrasTot - 1);
    x = A(ini:fin);
    if numel(x) < 256
        continue
    end
    [f, P] = fftSimple(x, Fs);
    idx = f >= 20 & f <= 3000;
    if ~any(idx)
        continue
    end
    [~, k] = max(P(idx));
    ff = f(idx);
    frecs(end + 1, 1) = ff(k); %#ok<AGROW>
end
if isempty(frecs)
    fNat = NaN;
    nUsados = 0;
else
    fNat = mean(frecs);
    nUsados = numel(frecs);
end
end

function locs = buscarPicos(env, umbralPct, radio, distMin, nMax)
N = numel(env);
umbral = umbralPct * max(env);
cLocs = [];
cPicos = [];
for i = radio + 1:N - radio
    v = env(i);
    if v < umbral
        continue
    end
    if v == max(env(i - radio:i + radio))
        cLocs(end + 1, 1) = i; %#ok<AGROW>
        cPicos(end + 1, 1) = v; %#ok<AGROW>
    end
end
locs = [];
if isempty(cLocs)
    return
end
[~, orden] = sort(cPicos, 'descend');
cLocs = cLocs(orden);
for i = 1:numel(cLocs)
    if isempty(locs) || all(abs(cLocs(i) - locs) >= distMin)
        locs(end + 1, 1) = cLocs(i); %#ok<AGROW>
    end
    if numel(locs) == nMax
        break
    end
end
locs = sort(locs);
end

function R = metricasAceleracion(carpeta, banda)
[Y, FsLista, t] = concatenarLVM(carpeta, 'A');
Fs = median(FsLista);
N = size(Y, 1);
Ntar = min(1000, max(1, floor(0.10 * N)));
Y = Y - mean(Y(1:Ntar, :), 1);
nCan = size(Y, 2);
rmsCan = zeros(1, nCan);
for c = 1:nCan
    rmsCan(c) = sqrt(mean(Y(:, c).^2));
end
if nCan == 1
    rmsTot = rmsCan(1);
    aMag = Y(:, 1);
else
    rmsTot = sqrt(mean(sum(Y.^2, 2)));
    aMag = sqrt(sum(Y.^2, 2));
end
[~, canal] = max(rmsCan);
[f, P] = fftSimple(Y(:, canal), Fs);
fModal = NaN;
ampModal = NaN;
chatter = false;
if ~isempty(f)
    idx = f >= banda(1) & f <= banda(2);
    if any(idx)
        [ampModal, k] = max(P(idx));
        ff = f(idx);
        fModal = ff(k);
    end
    resto = f >= 100 & f <= min(3000, Fs / 2) & ~(f >= banda(1) & f <= banda(2));
    if any(resto) && isfinite(ampModal)
        chatter = ampModal > 4 * max(median(P(resto)), eps);
    end
end
ter = floor(numel(aMag) / 3);
razon = NaN;
if ter >= 10
    r1 = sqrt(mean(aMag(1:ter).^2));
    r3 = sqrt(mean(aMag(end - ter + 1:end).^2));
    if r1 > 0
        razon = r3 / r1;
    end
end
[tPlot, aPlot] = reducir(t, Y, Fs, 8000);
[fPlot, pPlot] = reducirEspectro(f, P);
R.rmsA = rmsTot;
R.rmsCan = rmsCan;
R.Fs = Fs;
R.fModal = fModal;
R.ampModal = ampModal;
R.chatter = chatter;
R.razon = razon;
R.t = tPlot;
R.a = aPlot;
R.f = fPlot;
R.P = pPlot;
R.n = numel(FsLista);
R.canal = canal;
end

function R = metricasFuerza(carpeta)
[Y, FsLista, t] = concatenarLVM(carpeta, 'F');
if size(Y, 2) < 3
    error('Los archivos de fuerza deben traer tres canales (Fx, Fy, Fz).');
end
Y = Y(:, 1:3);
Fs = median(FsLista);
N = size(Y, 1);
Ntar = min(1000, max(1, floor(0.10 * N)));
Y = Y - mean(Y(1:Ntar, :), 1);
rms = zeros(1, 3);
for c = 1:3
    rms(c) = sqrt(mean(Y(:, c).^2));
end
[tPlot, fPlot] = reducir(t, Y, Fs, 8000);
R.rms = rms;
R.rmsR = sqrt(mean(sum(Y.^2, 2)));
R.Fs = Fs;
R.n = numel(FsLista);
R.t = tPlot;
R.F = fPlot;
end

function [Y, FsLista, t] = concatenarLVM(carpeta, prefijo)
archivos = listarLVM(carpeta, prefijo);
if isempty(archivos)
    error(['No se encontraron archivos %s*.lvm en:\n%s\n\n' ...
        'Si los datos están en un ZIP, descomprímelos primero.'], prefijo, carpeta);
end
bloques = {};
tiempos = {};
FsLista = [];
nCan = [];
tFin = -Inf;
for i = 1:numel(archivos)
    [Yi, Fsi, ti] = leerLVM(fullfile(carpeta, archivos(i).name));
    if isempty(Yi)
        continue
    end
    if isempty(ti) || any(~isfinite(ti))
        if isfinite(tFin)
            ti = tFin + (1:size(Yi, 1))' / Fsi;
        else
            ti = (0:size(Yi, 1) - 1)' / Fsi;
        end
    elseif ti(1) <= tFin
        ti = ti - ti(1) + tFin + 1 / Fsi;
    end
    tFin = ti(end);
    tiempos{end + 1} = ti; %#ok<AGROW>
    if isempty(nCan)
        nCan = size(Yi, 2);
    elseif size(Yi, 2) ~= nCan
        error('El archivo %s no tiene el mismo número de canales que los anteriores.', archivos(i).name);
    end
    if ~isempty(FsLista) && abs(Fsi - FsLista(1)) > 1
        warning('AnalisisChatter:Fs', ...
            'La frecuencia de muestreo cambia en %s.', archivos(i).name);
    end
    bloques{end + 1} = Yi; %#ok<AGROW>
    FsLista(end + 1) = Fsi; %#ok<AGROW>
end
if isempty(bloques)
    error('Los archivos de %s no contienen datos numéricos.', carpeta);
end
Y = vertcat(bloques{:});
t = vertcat(tiempos{:});
end

function archivos = listarLVM(carpeta, prefijo)
lista = dir(fullfile(carpeta, '*.lvm'));
if isempty(lista)
    lista = dir(fullfile(carpeta, '*.LVM'));
end
nums = [];
keep = false(numel(lista), 1);
for i = 1:numel(lista)
    token = regexp(lista(i).name, ['^' prefijo '_+(\d+)'], 'tokens', 'once', 'ignorecase');
    if ~isempty(token)
        keep(i) = true;
        nums(end + 1) = str2double(token{1}); %#ok<AGROW>
    end
end
archivos = lista(keep);
[~, orden] = sort(nums);
archivos = archivos(orden);
end

function [Y, Fs, t] = leerLVM(nombreArchivo)
fid = fopen(nombreArchivo, 'r');
if fid < 0
    error('No se pudo abrir:\n%s', nombreArchivo);
end
limpiar = onCleanup(@() fclose(fid));
deltaX = [];
nCanales = [];
enDatos = false;
while true
    linea = fgetl(fid);
    if ~ischar(linea)
        break
    end
    lineaTrim = strtrim(linea);
    if strncmpi(lineaTrim, 'Delta_X', 7)
        deltaX = numerosDeLinea(linea);
    elseif strncmpi(lineaTrim, 'Channels', 8)
        vals = numerosDeLinea(linea);
        if ~isempty(vals)
            nCanales = vals(1);
        end
    elseif strncmpi(lineaTrim, 'X_Value', 7)
        enDatos = true;
        break
    end
end
if ~enDatos
    error('No se encontró X_Value en:\n%s', nombreArchivo);
end
resto = fread(fid, inf, '*char')';
clear limpiar
[matriz, ~] = matrizDesdeTexto(resto, nCanales);
if isempty(matriz)
    error('No se encontraron datos numéricos en:\n%s', nombreArchivo);
end
Y = matriz(:, 2:end);
t = matriz(:, 1);
if isempty(deltaX) || any(~isfinite(deltaX))
    dt = diff(t);
    dt = dt(dt > 0 & dt < 1);
    if isempty(dt)
        error('No se pudo obtener Delta_X en:\n%s', nombreArchivo);
    end
    delta = median(dt);
else
    delta = median(deltaX);
end
Fs = 1 / delta;
end

function vals = numerosDeLinea(linea)
partes = regexp(linea, '\t', 'split');
vals = [];
for k = 2:numel(partes)
    v = str2double(strtrim(partes{k}));
    if ~isnan(v)
        vals(end + 1) = v; %#ok<AGROW>
    end
end
end

function [matriz, ncols] = matrizDesdeTexto(resto, nCanales)
candidatos = [];
if ~isempty(nCanales) && isfinite(nCanales) && nCanales >= 1
    candidatos = nCanales + 1;
end
candidatos = unique([candidatos, 2, 3, 4, 5], 'stable');
numeros = sscanf(resto, '%f');
matriz = [];
ncols = [];
for k = 1:numel(candidatos)
    nc = candidatos(k);
    if ~isempty(numeros) && mod(numel(numeros), nc) == 0
        matriz = reshape(numeros, nc, [])';
        ncols = nc;
        return
    end
end
lineas = regexp(resto, '\r\n|\n|\r', 'split');
filas = {};
for i = 1:numel(lineas)
    vals = sscanf(lineas{i}, '%f')';
    if numel(vals) >= 2
        filas{end + 1} = vals; %#ok<AGROW>
    end
end
if isempty(filas)
    return
end
ncols = max(cellfun(@numel, filas));
matriz = nan(numel(filas), ncols);
for i = 1:numel(filas)
    matriz(i, 1:numel(filas{i})) = filas{i};
end
end

function [f, P1] = fftSimple(x, Fs)
x = x(:);
x = x - mean(x);
N = numel(x);
if N < 8 || ~isfinite(Fs) || Fs <= 0
    f = [];
    P1 = [];
    return
end
n = (0:N - 1)';
ventana = 0.5 * (1 - cos(2 * pi * n / (N - 1)));
Y = fft(x .* ventana);
P2 = abs(Y / N);
mitad = floor(N / 2) + 1;
P1 = P2(1:mitad);
if numel(P1) > 2
    P1(2:end - 1) = 2 * P1(2:end - 1);
end
f = Fs * (0:mitad - 1)' / N;
end

function [tr, yr] = reducir(t, y, Fs, maxN)
n = size(y, 1);
nCan = size(y, 2);
t = t(:);
cortes = find(diff(t) > 5 / Fs);
inicios = [1; cortes + 1];
finales = [cortes; n];
paso = max(1, ceil(n / floor(maxN / 2)));
trCel = cell(numel(inicios), 1);
yrCel = cell(numel(inicios), 1);
for s = 1:numel(inicios)
    if paso == 1
        tS = t(inicios(s):finales(s));
        yS = y(inicios(s):finales(s), :);
    else
        bordes = inicios(s):paso:finales(s);
        tS = nan(2 * numel(bordes), 1);
        yS = nan(2 * numel(bordes), nCan);
        for b = 1:numel(bordes)
            idx = bordes(b):min(finales(s), bordes(b) + paso - 1);
            tS(2 * b - 1) = t(idx(1));
            tS(2 * b) = t(idx(end));
            for c = 1:nCan
                [vMin, iMin] = min(y(idx, c));
                [vMax, iMax] = max(y(idx, c));
                if iMin <= iMax
                    yS(2 * b - 1:2 * b, c) = [vMin; vMax];
                else
                    yS(2 * b - 1:2 * b, c) = [vMax; vMin];
                end
            end
        end
    end
    if s < numel(inicios)
        tS(end + 1, 1) = t(finales(s)); %#ok<AGROW>
        yS(end + 1, :) = NaN; %#ok<AGROW>
    end
    trCel{s} = tS;
    yrCel{s} = yS;
end
tr = vertcat(trCel{:});
yr = vertcat(yrCel{:});
end

function [f2, p2] = reducirEspectro(f, P)
if isempty(f)
    f2 = [];
    p2 = [];
    return
end
mask = f <= 4000;
f = f(mask);
P = P(mask);
if numel(f) <= 2500
    f2 = f;
    p2 = P;
    return
end
[~, ip] = max(P);
idx = unique([round(linspace(1, numel(f), 2500))'; ip]);
f2 = f(idx);
p2 = P(idx);
end
