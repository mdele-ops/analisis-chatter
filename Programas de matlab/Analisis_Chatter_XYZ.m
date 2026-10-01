function Analisis_Chatter_XYZ()
% ANALISIS DE CHATTER EN X, Y y Z
%
% Lee los archivos experimentales .lvm que dejes en las carpetas y calcula
% el analisis de chatter con aceleracion, fuerza y analisis modal.
%
% Estructura de cada prueba:
%
%   Nombre de la prueba/
%       Aceleracion/          A*.lvm con 1 canal, o con canales X Y Z
%           X/                o un archivo .lvm por eje
%           Y/
%           Z/
%       Fuerza/               F*.lvm con Fx, Fy y Fz
%           X/ Y/ Z/          opcional, un canal por carpeta
%       Modal/                impactos A*.lvm
%           X/ Y/ Z/          opcional
%
% El RMS, la FFT y el criterio de chatter se calculan con la senal tarada,
% sin suavizar. El suavizado solo se usa para dibujar la senal en el tiempo.
%
% Uso:
%   >> Analisis_Chatter_XYZ

fondo = [0.94 0.94 0.94];
raiz = fullfile(fileparts(mfilename('fullpath')), 'Datos_experimentales');
pruebas = repmat(plantillaPrueba(), 0, 1);
filaSel = [];

fig = figure( ...
    'Name', 'Analisis de chatter en X, Y y Z', ...
    'NumberTitle', 'off', ...
    'MenuBar', 'none', ...
    'ToolBar', 'none', ...
    'Color', fondo, ...
    'Position', [40 30 1380 800], ...
    'Resize', 'on');

panel = uipanel( ...
    'Parent', fig, ...
    'Units', 'normalized', ...
    'Position', [0.008 0.012 0.250 0.976], ...
    'BackgroundColor', fondo, ...
    'BorderType', 'line');

y = 0.985;
[H.lblTitulo, y] = uiTexto(panel, y, 'Datos experimentales', 0.030);
set(H.lblTitulo, 'FontSize', 13, 'FontWeight', 'bold');

[~, y] = uiTexto(panel, y, { ...
    'Copia los .lvm a las carpetas y pulsa Analizar.', ...
    'Aceleracion y fuerza pueden ir en X, Y y Z.', ...
    'El modal define la banda de chatter.'}, 0.072);

[~, y] = uiTexto(panel, y, 'Carpeta raiz', 0.022);
H.lblRaiz = uicontrol('Parent', panel, 'Style', 'text', ...
    'String', raiz, ...
    'Units', 'normalized', 'Position', [0.04, y - 0.055, 0.92, 0.055], ...
    'HorizontalAlignment', 'left', 'BackgroundColor', fondo, ...
    'FontSize', 8);
y = y - 0.062;

[~, y] = uiBoton(panel, y, 'Elegir carpeta raiz', 0.038, @elegirRaiz);
[~, y] = uiBoton(panel, y, 'Crear carpetas de pruebas', 0.038, @crearCarpetas);
[~, y] = uiBoton(panel, y, 'Analizar carpetas', 0.042, @analizar);

[~, y] = uiTexto(panel, y, 'Impacto modal a descartar (0 = ninguno)', 0.028);
[H.edDesc, y] = uiEdit(panel, y, '0', 0.034);

[~, y] = uiTexto(panel, y, 'Si la aceleracion trae un solo canal, asignarlo a', 0.028);
[H.popEje, y] = uiPopup(panel, y, {'X', 'Y', 'Z'}, 0.036);

[~, y] = uiTexto(panel, y, { ...
    'Nombres validos de carpeta:', ...
    'Aceleracion, Fuerza, Modal.', ...
    'Dentro, subcarpetas X, Y y Z.', ...
    'Archivos: A_1.lvm, A__1.lvm, F_1.lvm.'}, 0.078);

H.btnExport = uicontrol('Parent', panel, 'Style', 'pushbutton', ...
    'String', 'Exportar resumen CSV', ...
    'Units', 'normalized', 'Position', [0.04, 0.012, 0.92, 0.040], ...
    'FontSize', 10, 'Callback', @exportarCsv);

H.status = uicontrol('Parent', fig, 'Style', 'text', ...
    'String', 'Elige la carpeta raiz o crea las carpetas, copia los .lvm y pulsa Analizar.', ...
    'Units', 'normalized', 'Position', [0.268 0.012 0.72 0.032], ...
    'HorizontalAlignment', 'left', 'BackgroundColor', fondo, 'FontSize', 9);

columnas = { ...
    'Prueba', 'Prof. (mm)', 'Refrigerante', 'Herramienta', ...
    'RMS X', 'RMS Y', 'RMS Z', ...
    'Fx', 'Fy', 'Fz', ...
    'fn (Hz)', 'Chatter', 'Eje', 'Indice'};

H.tabla = uitable( ...
    'Parent', fig, ...
    'Units', 'normalized', ...
    'Position', [0.268 0.640 0.722 0.345], ...
    'ColumnName', columnas, ...
    'ColumnWidth', {170, 70, 110, 90, 62, 62, 62, 58, 58, 58, 70, 62, 40, 58}, ...
    'RowStriping', 'on', ...
    'FontSize', 9, ...
    'CellSelectionCallback', @alSeleccionar);

tabs = uitabgroup(fig, 'Units', 'normalized', 'Position', [0.268 0.050 0.722 0.580]);

tabA = uitab(tabs, 'Title', 'Aceleracion XYZ');
H.axA = crearEjes(tabA, [0.08 0.14 0.88 0.78]);

tabF = uitab(tabs, 'Title', 'Fuerza XYZ');
H.axF = crearEjes(tabF, [0.08 0.14 0.88 0.78]);

tabE = uitab(tabs, 'Title', 'Espectro XYZ');
H.axE = crearEjes(tabE, [0.08 0.14 0.88 0.78]);

tabM = uitab(tabs, 'Title', 'Modal');
H.axM = crearEjes(tabM, [0.10 0.16 0.84 0.74]);

tabC = uitab(tabs, 'Title', 'Resultado');
H.txt = uicontrol('Parent', tabC, 'Style', 'edit', ...
    'Max', 2, 'Min', 0, 'Enable', 'inactive', ...
    'HorizontalAlignment', 'left', ...
    'FontName', 'Consolas', 'FontSize', 10, ...
    'Units', 'normalized', 'Position', [0.02 0.02 0.96 0.96], ...
    'BackgroundColor', 'white');

refrescar();

    function elegirRaiz(~, ~)
        inicio = raiz;
        if ~isfolder(inicio)
            inicio = pwd;
        end
        carpeta = uigetdir(inicio, 'Selecciona la carpeta donde estan las pruebas');
        if isequal(carpeta, 0)
            return
        end
        raiz = carpeta;
        set(H.lblRaiz, 'String', raiz, 'TooltipString', raiz);
        ponerEstado(['Carpeta raiz: ' raiz]);
    end

    function crearCarpetas(~, ~)
        destino = uigetdir(pwd, 'Elige donde crear las carpetas de las pruebas');
        if isequal(destino, 0)
            return
        end
        condiciones = { ...
            'Sin refrigerante - Nueva', ...
            'Sin refrigerante - Desgastada', ...
            'Con refrigerante - Nueva', ...
            'Con refrigerante - Desgastada'};
        profundidades = {'0.5 mm', '1 mm', '2 mm', '2.5 mm', '3 mm'};
        for i = 1:numel(condiciones)
            for j = 1:numel(profundidades)
                base = fullfile(destino, condiciones{i}, profundidades{j});
                mkdir(fullfile(base, 'Aceleracion', 'X'));
                mkdir(fullfile(base, 'Aceleracion', 'Y'));
                mkdir(fullfile(base, 'Aceleracion', 'Z'));
                mkdir(fullfile(base, 'Fuerza'));
                mkdir(fullfile(base, 'Modal'));
            end
        end
        raiz = destino;
        set(H.lblRaiz, 'String', raiz, 'TooltipString', raiz);
        msgbox(sprintf(['Carpetas creadas en:\n%s\n\n' ...
            'Aceleracion de un solo canal: dejala en Aceleracion, o en X, Y o Z.\n' ...
            'Aceleracion triaxial en un solo archivo: dejala en Aceleracion.\n' ...
            'Fuerza Fx Fy Fz: dejala en Fuerza.\n' ...
            'Impactos del modal: dejalo en Modal.\n' ...
            'Descomprime los ZIP antes de analizar.'], destino), ...
            'Carpetas listas');
        ponerEstado('Carpetas creadas. Copia los .lvm y pulsa Analizar.');
    end

    function analizar(~, ~)
        if ~isfolder(raiz)
            errordlg('La carpeta raiz no existe. Elige una carpeta o crea la estructura.', 'Sin carpeta');
            return
        end
        descartar = str2double(strtrim(get(H.edDesc, 'String')));
        if ~isfinite(descartar) || descartar < 0
            errordlg('El impacto a descartar debe ser un entero mayor o igual que cero.', 'Dato no valido');
            return
        end
        descartar = round(descartar);
        ejeUnico = valorPopup(H.popEje);
        wb = waitbar(0, 'Buscando pruebas...');
        try
            encontradas = descubrirPruebas(raiz);
            if isempty(encontradas)
                close(wb);
                if hayEstructura(raiz)
                    errordlg(sprintf(['Las carpetas existen, pero todavia no tienen archivos .lvm:\n%s\n\n' ...
                        'Copia la aceleracion, la fuerza y el modal, y pulsa Analizar otra vez.'], raiz), ...
                        'Carpetas vacias');
                else
                    errordlg(sprintf(['No encontre pruebas en:\n%s\n\n' ...
                        'Cada prueba necesita una carpeta Aceleracion, Fuerza o Modal.\n' ...
                        'Dentro puedes usar subcarpetas X, Y y Z.'], raiz), ...
                        'Sin datos');
                end
                ponerEstado('No se encontraron archivos .lvm para analizar.');
                return
            end
            nuevas = repmat(plantillaPrueba(), 0, 1);
            for i = 1:numel(encontradas)
                waitbar(i / numel(encontradas), wb, ...
                    sprintf('Analizando %d de %d', i, numel(encontradas)));
                nuevas(i, 1) = analizarPrueba(encontradas(i), descartar, ejeUnico); %#ok<AGROW>
            end
            close(wb);
            pruebas = calcularIndices(nuevas);
            if isempty(pruebas)
                filaSel = [];
            else
                filaSel = 1;
            end
            refrescar();
            nOk = 0;
            for i = 1:numel(pruebas)
                if isempty(pruebas(i).error)
                    nOk = nOk + 1;
                end
            end
            ponerEstado(sprintf('Listo: %d pruebas, %d analizadas sin error.', numel(pruebas), nOk));
        catch ME
            if ishandle(wb)
                close(wb);
            end
            errordlg(ME.message, 'No se pudo analizar');
            ponerEstado('El analisis se detuvo por un error.');
        end
    end

    function alSeleccionar(~, evento)
        if isempty(evento.Indices)
            return
        end
        filaSel = evento.Indices(1, 1);
        graficarAceleracion();
        graficarFuerza();
        graficarEspectro();
    end

    function exportarCsv(~, ~)
        if isempty(pruebas)
            errordlg('No hay pruebas. Pulsa Analizar primero.', 'Exportar');
            return
        end
        [archivo, carpeta] = uiputfile('resumen_chatter_xyz.csv', 'Exportar resumen');
        if isequal(archivo, 0)
            return
        end
        ruta = fullfile(carpeta, archivo);
        fid = fopen(ruta, 'w');
        if fid < 0
            errordlg('No se pudo crear el CSV.', 'Exportar');
            return
        end
        limpiar = onCleanup(@() fclose(fid));
        fprintf(fid, ['prueba,profundidad_mm,refrigerante,herramienta,' ...
            'rms_ax,rms_ay,rms_az,rms_a,rms_fx,rms_fy,rms_fz,rms_f,' ...
            'fn_x,fn_y,fn_z,fn_Hz,pico_Hz,amp_modal,chatter,eje_chatter,' ...
            'crecimiento,indice,archivos,notas,error\n']);
        for i = 1:numel(pruebas)
            p = pruebas(i);
            fprintf(fid, '%s,%.8g,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%d,%s,%s,%s,%s,%s,%s\n', ...
                csvTexto(p.nombre), p.profundidad, csvTexto(p.refrigerante), csvTexto(p.herramienta), ...
                csvNum(p.rmsAx), csvNum(p.rmsAy), csvNum(p.rmsAz), csvNum(p.rmsA), ...
                csvNum(p.rmsFx), csvNum(p.rmsFy), csvNum(p.rmsFz), csvNum(p.rmsF), ...
                csvNum(p.fnX), csvNum(p.fnY), csvNum(p.fnZ), csvNum(p.fNatural), ...
                csvNum(p.fModal), csvNum(p.ampModal), logical(p.chatter), csvTexto(p.ejeChatter), ...
                csvNum(p.razonCrecimiento), csvNum(p.indice), csvTexto(p.archivos), ...
                csvTexto(p.notas), csvTexto(p.error));
        end
        clear limpiar
        ponerEstado(['CSV exportado: ' ruta]);
    end

    function refrescar()
        actualizarTabla();
        graficarAceleracion();
        graficarFuerza();
        graficarEspectro();
        graficarModal();
        set(H.txt, 'String', redactar(pruebas));
        drawnow
    end

    function actualizarTabla()
        if isempty(pruebas)
            set(H.tabla, 'Data', cell(0, 14));
            return
        end
        datos = cell(numel(pruebas), 14);
        for i = 1:numel(pruebas)
            p = pruebas(i);
            if ~isempty(p.error)
                ch = 'Error';
            elseif p.chatter
                ch = 'Si';
            else
                ch = 'No';
            end
            datos(i, :) = { ...
                p.nombre, fmt(p.profundidad, '%.4g'), p.refrigerante, p.herramienta, ...
                fmt(p.rmsAx, '%.4f'), fmt(p.rmsAy, '%.4f'), fmt(p.rmsAz, '%.4f'), ...
                fmt(p.rmsFx, '%.4f'), fmt(p.rmsFy, '%.4f'), fmt(p.rmsFz, '%.4f'), ...
                fmt(p.fNatural, '%.1f'), ch, p.ejeChatter, fmt(p.indice, '%.3f')};
        end
        set(H.tabla, 'Data', datos);
    end

    function graficarAceleracion()
        graficarTiempo(H.axA, 'tA', 'aA', {'X', 'Y', 'Z'}, ...
            'Tiempo [s]', 'Aceleracion [g], suavizada solo al graficar', 'aceleracion');
    end

    function graficarFuerza()
        graficarTiempo(H.axF, 'tF', 'F', {'F_x', 'F_y', 'F_z'}, ...
            'Tiempo [s]', 'Fuerza [V], suavizada solo al graficar', 'fuerza');
    end

    function graficarTiempo(ax, campoT, campoY, nombres, xlab, ylab, tipo)
        cla(ax);
        p = pruebaSeleccionada();
        if isempty(p)
            mostrarVacio(ax, 'Analiza las carpetas y selecciona una prueba.');
            return
        end
        if ~isempty(p.error)
            mostrarVacio(ax, p.error);
            return
        end
        t = p.(campoT);
        yv = p.(campoY);
        if isempty(t) || isempty(yv)
            mostrarVacio(ax, ['Esta prueba no tiene ' tipo '.']);
            return
        end
        axis(ax, 'on');
        hold(ax, 'on');
        colores = coloresEjes();
        hay = false;
        for c = 1:min(3, size(yv, 2))
            if all(~isfinite(yv(:, c)))
                continue
            end
            plot(ax, t, yv(:, c), 'Color', colores(c, :), 'LineWidth', 0.9, ...
                'DisplayName', nombres{c});
            hay = true;
        end
        hold(ax, 'off');
        if ~hay
            mostrarVacio(ax, ['Esta prueba no tiene ' tipo ' utilizable.']);
            return
        end
        grid(ax, 'on');
        box(ax, 'on');
        xlabel(ax, xlab, 'Interpreter', 'none');
        ylabel(ax, ylab, 'Interpreter', 'none');
        title(ax, p.nombre, 'Interpreter', 'none');
        lg = legend(ax, 'Location', 'best');
        set(lg, 'Interpreter', 'none');
    end

    function graficarEspectro()
        cla(H.axE);
        p = pruebaSeleccionada();
        if isempty(p)
            mostrarVacio(H.axE, 'Analiza las carpetas y selecciona una prueba.');
            return
        end
        if isempty(p.fFFT)
            mostrarVacio(H.axE, 'Esta prueba no tiene espectro de aceleracion.');
            return
        end
        axis(H.axE, 'on');
        hold(H.axE, 'on');
        colores = coloresEjes();
        nombres = {'X', 'Y', 'Z'};
        for c = 1:min(3, size(p.pFFT, 2))
            if all(~isfinite(p.pFFT(:, c)))
                continue
            end
            plot(H.axE, p.fFFT, p.pFFT(:, c), 'Color', colores(c, :), ...
                'LineWidth', 1, 'DisplayName', nombres{c});
        end
        if numel(p.banda) == 2 && all(isfinite(p.banda))
            yl = ylim(H.axE);
            line(H.axE, [p.banda(1) p.banda(1)], yl, ...
                'Color', [0.45 0.45 0.45], 'LineStyle', '--', 'LineWidth', 1, ...
                'HandleVisibility', 'off');
            line(H.axE, [p.banda(2) p.banda(2)], yl, ...
                'Color', [0.45 0.45 0.45], 'LineStyle', '--', 'LineWidth', 1, ...
                'HandleVisibility', 'off');
            ylim(H.axE, yl);
        end
        hold(H.axE, 'off');
        grid(H.axE, 'on');
        box(H.axE, 'on');
        xlabel(H.axE, 'Frecuencia [Hz]', 'Interpreter', 'none');
        ylabel(H.axE, 'Amplitud [g]', 'Interpreter', 'none');
        if p.chatter
            estado = 'chatter: si';
        else
            estado = 'chatter: no';
        end
        title(H.axE, sprintf('%s | %s | pico %s Hz | %s', ...
            p.nombre, p.ejeChatter, fmt(p.fModal, '%.1f'), estado), ...
            'Interpreter', 'none');
        if ~isempty(p.fFFT)
            xlim(H.axE, [0, min(4000, max(p.fFFT))]);
        end
        lg = legend(H.axE, 'Location', 'best');
        set(lg, 'Interpreter', 'none');
    end

    function graficarModal()
        cla(H.axM);
        if isempty(pruebas)
            mostrarVacio(H.axM, 'Analiza una carpeta Modal para ver la frecuencia natural.');
            return
        end
        vals = [];
        etiquetas = {};
        for i = 1:numel(pruebas)
            if isfinite(pruebas(i).fNatural)
                vals(end + 1) = pruebas(i).fNatural; %#ok<AGROW>
                etiquetas{end + 1} = pruebas(i).nombre; %#ok<AGROW>
            end
        end
        if isempty(vals)
            mostrarVacio(H.axM, 'Ninguna prueba tiene frecuencia natural.');
            return
        end
        axis(H.axM, 'on');
        bar(H.axM, vals, 'FaceColor', [0.20 0.45 0.70]);
        grid(H.axM, 'on');
        box(H.axM, 'on');
        ylabel(H.axM, 'Frecuencia natural [Hz]', 'Interpreter', 'none');
        title(H.axM, 'Frecuencia natural por prueba', 'Interpreter', 'none');
        set(H.axM, 'XTick', 1:numel(vals), 'XTickLabel', etiquetas, ...
            'XTickLabelRotation', 25, 'TickLabelInterpreter', 'none');
        xlim(H.axM, [0.4, numel(vals) + 0.6]);
    end

    function p = pruebaSeleccionada()
        p = [];
        if isempty(pruebas) || isempty(filaSel) || filaSel < 1 || filaSel > numel(pruebas)
            return
        end
        p = pruebas(filaSel);
    end

    function ponerEstado(texto)
        set(H.status, 'String', texto);
        drawnow
    end

end

function info = descubrirPruebas(raiz)
info = struct('carpeta', {}, 'rel', {}, 'aceleracion', {}, 'fuerza', {}, 'modal', {});
carpetas = listarCarpetas(raiz);
grupos = struct();
claves = {};
for i = 1:numel(carpetas)
    [~, nombre] = fileparts(carpetas{i});
    tipo = clasificarCarpeta(nombre);
    if isempty(tipo) || ~tieneDatos(carpetas{i})
        continue
    end
    padre = fileparts(carpetas{i});
    if isempty(padre)
        continue
    end
    clave = padre;
    idx = find(strcmp(claves, clave), 1);
    if isempty(idx)
        claves{end + 1} = clave; %#ok<AGROW>
        idx = numel(claves);
        grupos(idx).carpeta = padre; %#ok<AGROW>
        grupos(idx).aceleracion = '';
        grupos(idx).fuerza = '';
        grupos(idx).modal = '';
    end
    grupos(idx).(tipo) = carpetas{i};
end
for i = 1:numel(claves)
    if isempty(grupos(i).aceleracion) && isempty(grupos(i).fuerza) && isempty(grupos(i).modal)
        continue
    end
    rel = rutasRelativa(raiz, grupos(i).carpeta);
    info(end + 1).carpeta = grupos(i).carpeta; %#ok<AGROW>
    info(end).rel = rel;
    info(end).aceleracion = grupos(i).aceleracion;
    info(end).fuerza = grupos(i).fuerza;
    info(end).modal = grupos(i).modal;
end
if isempty(info)
    info = descubrirSueltos(raiz);
end
if ~isempty(info)
    [~, orden] = sort({info.rel});
    info = info(orden);
end
end

function info = descubrirSueltos(raiz)
info = struct('carpeta', {}, 'rel', {}, 'aceleracion', {}, 'fuerza', {}, 'modal', {});
carpetas = listarCarpetas(raiz);
for i = 1:numel(carpetas)
    if ~tieneDatos(carpetas{i})
        continue
    end
    [~, nombre] = fileparts(carpetas{i});
    if any(strcmpi(nombre, {'X', 'Y', 'Z'}))
        continue
    end
    tipoNombre = clasificarCarpeta(nombre);
    item.carpeta = carpetas{i};
    item.rel = rutasRelativa(raiz, carpetas{i});
    item.aceleracion = '';
    item.fuerza = '';
    item.modal = '';
    if strcmp(tipoNombre, 'fuerza')
        item.fuerza = carpetas{i};
    elseif strcmp(tipoNombre, 'modal')
        item.modal = carpetas{i};
    elseif strcmp(tipoNombre, 'aceleracion')
        item.aceleracion = carpetas{i};
    else
        archivos = listarLVM(carpetas{i}, '');
        nF = 0;
        nA = 0;
        for k = 1:numel(archivos)
            if ~isempty(regexp(archivos(k).name, '^F', 'once', 'ignorecase'))
                nF = nF + 1;
            else
                nA = nA + 1;
            end
        end
        if nF > nA
            item.fuerza = carpetas{i};
        else
            item.aceleracion = carpetas{i};
        end
    end
    info(end + 1) = item; %#ok<AGROW>
end
end

function tf = hayEstructura(raiz)
tf = false;
if ~isfolder(raiz)
    return
end
carpetas = listarCarpetas(raiz);
for i = 1:numel(carpetas)
    [~, nombre] = fileparts(carpetas{i});
    if ~isempty(clasificarCarpeta(nombre))
        tf = true;
        return
    end
end
end

function tf = tieneDatos(carpeta)
tf = false;
if ~isfolder(carpeta)
    return
end
if ~isempty(listarLVM(carpeta, ''))
    tf = true;
    return
end
ejes = {'X', 'Y', 'Z'};
for k = 1:3
    if ~isempty(listarLVM(fullfile(carpeta, ejes{k}), ''))
        tf = true;
        return
    end
end
end

function p = analizarPrueba(info, descartar, ejeUnico)
p = plantillaPrueba();
p.nombre = strrep(info.rel, [filesep filesep], filesep);
if isempty(p.nombre)
    [~, p.nombre] = fileparts(info.carpeta);
end
meta = leerMeta(info.rel);
p.profundidad = meta.profundidad;
p.refrigerante = meta.refrigerante;
p.herramienta = meta.herramienta;
p.banda = [1300 1550];
notas = {};
fallos = {};
if ~isempty(info.modal)
    try
        [fn, nImp, detalle] = frecuenciaNatural(info.modal, descartar);
        p.fnX = fn(1);
        p.fnY = fn(2);
        p.fnZ = fn(3);
        p.fNatural = fnRepresentativa(fn);
        if isfinite(p.fNatural)
            p.banda = [max(20, p.fNatural - 125), p.fNatural + 125];
            notas{end + 1} = sprintf('Modal: %s.', detalle); %#ok<AGROW>
        else
            notas{end + 1} = 'Modal sin frecuencia natural. Banda 1300-1550 Hz.'; %#ok<AGROW>
        end
        p.nModal = nImp;
    catch ME
        fallos{end + 1} = ['Modal: ' ME.message]; %#ok<AGROW>
    end
end
if ~isempty(info.aceleracion)
    try
        A = metricasAceleracion(info.aceleracion, p.banda, ejeUnico);
        p.rmsAx = A.rms(1);
        p.rmsAy = A.rms(2);
        p.rmsAz = A.rms(3);
        p.rmsA = A.rmsR;
        p.fModal = A.fModal;
        p.ampModal = A.ampModal;
        p.chatter = A.chatter;
        p.ejeChatter = A.eje;
        p.razonCrecimiento = A.razon;
        p.tA = A.t;
        p.aA = A.y;
        p.fFFT = A.f;
        p.pFFT = A.P;
        p.chatterX = A.chatterEje(1);
        p.chatterY = A.chatterEje(2);
        p.chatterZ = A.chatterEje(3);
        notas{end + 1} = A.nota; %#ok<AGROW>
    catch ME
        fallos{end + 1} = ['Aceleracion: ' ME.message]; %#ok<AGROW>
    end
end
if ~isempty(info.fuerza)
    try
        Fz = metricasFuerza(info.fuerza);
        p.rmsFx = Fz.rms(1);
        p.rmsFy = Fz.rms(2);
        p.rmsFz = Fz.rms(3);
        p.rmsF = Fz.rmsR;
        p.tF = Fz.t;
        p.F = Fz.y;
        notas{end + 1} = Fz.nota; %#ok<AGROW>
    catch ME
        fallos{end + 1} = ['Fuerza: ' ME.message]; %#ok<AGROW>
    end
end
if ~isempty(fallos) && isempty(notas)
    p.error = strjoin(fallos, ' ');
end
if ~isempty(fallos)
    notas = [notas, fallos]; %#ok<AGROW>
end
p.notas = strjoin(notas, ' ');
p.archivos = sprintf('A:%s | F:%s | M:%s', ...
    marcaRuta(info.aceleracion), marcaRuta(info.fuerza), marcaRuta(info.modal));
end

function A = metricasAceleracion(carpeta, banda, ejeUnico)
[Y, Fs, etiquetas, nota] = cargarXYZ(carpeta, 'A', ejeUnico);
Y = tarar(Y);
rms = rmsCanales(Y);
presentes = canalesPresentes(Y);
if ~any(presentes)
    error('La carpeta de aceleracion no tiene datos numericos:\n%s', carpeta);
end
mag = magnitud(Y);
rmsR = sqrt(mean(mag.^2));
[f, P] = fftCanales(Y, Fs);
[fModal, ampModal, chatter, eje, chatterEje] = evaluarChatter(f, P, banda, etiquetas);
ter = floor(numel(mag) / 3);
razon = NaN;
if ter >= 10
    r1 = sqrt(mean(mag(1:ter).^2));
    r3 = sqrt(mean(mag(end - ter + 1:end).^2));
    if r1 > 0
        razon = r3 / r1;
    end
end
t = (0:size(Y, 1) - 1)' / Fs;
[tPlot, yPlot] = reducir(t, suavizarVisual(Y, Fs), 8000);
[fPlot, pPlot] = reducirEspectro(f, P);
A.rms = rms;
A.rmsR = rmsR;
A.fModal = fModal;
A.ampModal = ampModal;
A.chatter = chatter;
A.chatterEje = chatterEje;
A.eje = eje;
A.razon = razon;
A.t = tPlot;
A.y = yPlot;
A.f = fPlot;
A.P = pPlot;
A.nota = sprintf('Aceleracion %s. Fs %.0f Hz. %s', strjoin(etiquetas(presentes), ','), Fs, nota);
end

function F = metricasFuerza(carpeta)
[Y, Fs, etiquetas, nota] = cargarXYZ(carpeta, 'F', 'X');
if size(Y, 2) < 3 || sum(canalesPresentes(Y)) < 3
    error(['La fuerza debe traer Fx, Fy y Fz en un archivo, ' ...
        'o en subcarpetas X, Y y Z.\nCarpeta:\n%s'], carpeta);
end
Y = tarar(Y);
rms = rmsCanales(Y);
mag = magnitud(Y);
t = (0:size(Y, 1) - 1)' / Fs;
[tPlot, yPlot] = reducir(t, suavizarVisual(Y, Fs), 8000);
F.rms = rms;
F.rmsR = sqrt(mean(mag.^2));
F.t = tPlot;
F.y = yPlot;
F.nota = sprintf('Fuerza %s. Fs %.0f Hz. %s', strjoin(etiquetas, ','), Fs, nota);
end

function [Y, Fs, etiquetas, nota] = cargarXYZ(carpeta, prefijo, ejeUnico)
ejes = {'X', 'Y', 'Z'};
usadas = cell(1, 3);
bloques = cell(1, 3);
FsEje = nan(1, 3);
for k = 1:3
    sub = fullfile(carpeta, ejes{k});
    if isfolder(sub)
        [yk, fk] = concatenarLVM(sub, prefijo, false);
        if ~isempty(yk)
            bloques{k} = yk(:, 1);
            FsEje(k) = fk;
            usadas{k} = ejes{k};
        end
    end
end
if any(~cellfun(@isempty, bloques))
    Fs = median(FsEje(isfinite(FsEje)));
    for k = 1:3
        if ~isempty(bloques{k}) && abs(FsEje(k) - Fs) > 1
            error('La frecuencia de muestreo de %s no coincide con los otros ejes.', ejes{k});
        end
    end
    n = inf;
    for k = 1:3
        if ~isempty(bloques{k})
            n = min(n, numel(bloques{k}));
        end
    end
    Y = nan(n, 3);
    for k = 1:3
        if ~isempty(bloques{k})
            Y(:, k) = bloques{k}(1:n);
        end
    end
    etiquetas = ejes;
    nota = 'Ejes leidos desde subcarpetas X, Y y Z.';
    return
end

[Yall, Fs, nombres] = concatenarLVM(carpeta, prefijo, true);
if isempty(Yall)
    error('No hay archivos .lvm en:\n%s', carpeta);
end
idx = mapearEjes(nombres, size(Yall, 2), ejeUnico);
Y = nan(size(Yall, 1), 3);
etiquetas = {'X', 'Y', 'Z'};
for k = 1:3
    if idx(k) >= 1 && idx(k) <= size(Yall, 2)
        Y(:, k) = Yall(:, idx(k));
    end
end
if sum(idx > 0) == 1
    nota = sprintf('Un canal asignado a %s.', etiquetas{idx > 0});
else
    nota = sprintf('Canales del archivo: %s.', strjoin(nombres, ', '));
end
end

function [fn, nImp, detalle] = frecuenciaNatural(carpeta, descartar)
fn = nan(1, 3);
nImp = 0;
detalle = 'sin impactos';
[Y, Fs, etiquetas] = cargarXYZ(carpeta, 'A', 'X');
if isempty(Y)
    return
end
partes = {};
for c = 1:3
    if all(~isfinite(Y(:, c)))
        continue
    end
    [fn(c), n] = fnDeCanal(Y(:, c), Fs, descartar);
    nImp = nImp + n;
    if isfinite(fn(c))
        partes{end + 1} = sprintf('%s %.1f Hz (%d impactos)', etiquetas{c}, fn(c), n); %#ok<AGROW>
    end
end
if isempty(partes)
    detalle = 'no se detectaron impactos utiles';
else
    detalle = strjoin(partes, '; ');
end
end

function [fNat, nUsados] = fnDeCanal(A, Fs, descartar)
A = A(isfinite(A));
A = A - mean(A);
fNat = NaN;
nUsados = 0;
if numel(A) < 256 || ~isfinite(Fs) || Fs <= 0
    return
end
radio = max(1, round(0.005 * Fs));
distMin = round(0.03 * Fs);
env = movmean(abs(A), max(1, round(0.005 * Fs)));
locs = buscarPicos(env, 0.15, radio, distMin, 6);
if isempty(locs)
    locs = buscarPicos(env, 0.08, radio, distMin, 6);
end
if isempty(locs)
    return
end
if descartar >= 1 && descartar <= numel(locs)
    locs(descartar) = [];
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
if ~isempty(frecs)
    fNat = mean(frecs);
    nUsados = numel(frecs);
end
end

function [fModal, ampModal, chatter, eje, chatterEje] = evaluarChatter(f, P, banda, etiquetas)
fModal = NaN;
ampModal = NaN;
chatter = false;
eje = '';
chatterEje = false(1, 3);
if isempty(f)
    return
end
mejores = nan(1, 3);
picosF = nan(1, 3);
for c = 1:size(P, 2)
    Pc = P(:, c);
    if all(~isfinite(Pc))
        continue
    end
    idx = f >= banda(1) & f <= banda(2);
    if ~any(idx)
        continue
    end
    [amp, k] = max(Pc(idx));
    ff = f(idx);
    picosF(c) = ff(k);
    mejores(c) = amp;
    resto = f >= 100 & f <= min(3000, max(f)) & ~(f >= banda(1) & f <= banda(2));
    fondo = Pc(resto);
    fondo = fondo(isfinite(fondo));
    if ~isempty(fondo) && isfinite(amp)
        chatterEje(c) = amp > 4 * max(median(fondo), eps);
    end
end
if ~any(isfinite(mejores))
    return
end
[ampModal, cMax] = max(mejores);
fModal = picosF(cMax);
chatter = any(chatterEje);
activos = etiquetas(chatterEje);
if isempty(activos)
    eje = etiquetas{cMax};
else
    eje = strjoin(activos, ',');
end
end

function [Y, Fs, nombres] = concatenarLVM(carpeta, prefijo, exigir)
archivos = listarLVM(carpeta, prefijo);
Y = [];
Fs = NaN;
nombres = {};
if isempty(archivos)
    if exigir
        error(['No se encontraron archivos .lvm en:\n%s\n\n' ...
            'Si estan en ZIP, descomprimelos primero.'], carpeta);
    end
    return
end
bloques = {};
FsLista = [];
nCan = [];
nombres = {};
for i = 1:numel(archivos)
    [Yi, Fsi, nombresI] = leerLVM(fullfile(carpeta, archivos(i).name));
    if isempty(Yi)
        continue
    end
    if isempty(nCan)
        nCan = size(Yi, 2);
        nombres = nombresI;
    elseif size(Yi, 2) ~= nCan
        error('El archivo %s no tiene los mismos canales que los anteriores.', archivos(i).name);
    end
    if ~isempty(FsLista) && abs(Fsi - FsLista(1)) > 1
        warning('AnalisisChatterXYZ:Fs', ...
            'La frecuencia de muestreo cambia en %s.', archivos(i).name);
    end
    bloques{end + 1} = Yi; %#ok<AGROW>
    FsLista(end + 1) = Fsi; %#ok<AGROW>
end
if isempty(bloques)
    if exigir
        error('Los archivos de %s no contienen datos numericos.', carpeta);
    end
    return
end
Y = vertcat(bloques{:});
Fs = median(FsLista);
end

function archivos = listarLVM(carpeta, prefijo)
if ~isfolder(carpeta)
    archivos = dir(fullfile(carpeta, '*.lvm'));
    archivos = archivos([]);
    return
end
lista = dir(fullfile(carpeta, '*.lvm'));
if isempty(lista)
    lista = dir(fullfile(carpeta, '*.LVM'));
end
lista = lista(~[lista.isdir]);
if isempty(lista)
    archivos = lista;
    return
end
if nargin < 2 || isempty(prefijo)
    archivos = ordenarPorNumero(lista);
    return
end
nums = nan(numel(lista), 1);
keep = false(numel(lista), 1);
for i = 1:numel(lista)
    token = regexp(lista(i).name, [prefijo '_*(\d+)'], 'tokens', 'once', 'ignorecase');
    if ~isempty(token)
        keep(i) = true;
        nums(i) = str2double(token{1});
    end
end
if any(keep)
    sel = lista(keep);
    nums = nums(keep);
    [~, orden] = sort(nums);
    archivos = sel(orden);
else
    archivos = ordenarPorNumero(lista);
end
end

function archivos = ordenarPorNumero(lista)
nums = nan(numel(lista), 1);
for i = 1:numel(lista)
    token = regexp(lista(i).name, '(\d+)', 'tokens', 'once');
    if ~isempty(token)
        nums(i) = str2double(token{1});
    else
        nums(i) = i;
    end
end
[~, orden] = sort(nums);
archivos = lista(orden);
end

function [Y, Fs, nombres] = leerLVM(nombreArchivo)
fid = fopen(nombreArchivo, 'r');
if fid < 0
    error('No se pudo abrir:\n%s', nombreArchivo);
end
limpiar = onCleanup(@() fclose(fid));
deltaX = [];
nCanales = [];
nombres = {};
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
        nombres = nombresDeCanales(linea);
        enDatos = true;
        break
    end
end
if ~enDatos
    error('No se encontro X_Value en:\n%s', nombreArchivo);
end
resto = fread(fid, inf, '*char')';
clear limpiar
if ~isempty(nCanales) && isfinite(nCanales)
    esperadas = nCanales + 1;
else
    esperadas = [];
end
[matriz, ~] = matrizDesdeTexto(resto, esperadas);
if isempty(matriz)
    error('No se encontraron datos numericos en:\n%s', nombreArchivo);
end
Y = matriz(:, 2:end);
if isempty(nombres)
    nombres = nombresPorDefecto(size(Y, 2));
elseif numel(nombres) < size(Y, 2)
    extra = nombresPorDefecto(size(Y, 2));
    nombres = [nombres, extra(numel(nombres) + 1:end)];
elseif numel(nombres) > size(Y, 2)
    nombres = nombres(1:size(Y, 2));
end
if isempty(deltaX) || any(~isfinite(deltaX))
    t = matriz(:, 1);
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

function nombres = nombresDeCanales(linea)
partes = regexp(linea, '\t', 'split');
nombres = {};
for k = 2:numel(partes)
    nombre = strtrim(partes{k});
    if isempty(nombre)
        continue
    end
    if strcmpi(nombre, 'Comment')
        continue
    end
    nombres{end + 1} = nombre; %#ok<AGROW>
end
end

function nombres = nombresPorDefecto(n)
base = {'X', 'Y', 'Z'};
nombres = cell(1, n);
for i = 1:n
    if i <= 3
        nombres{i} = base{i};
    else
        nombres{i} = sprintf('Canal %d', i);
    end
end
end

function idx = mapearEjes(nombres, nCan, ejeUnico)
idx = zeros(1, 3);
usados = false(1, nCan);
ejes = {'x', 'y', 'z'};
for k = 1:3
    for c = 1:numel(nombres)
        if usados(min(c, nCan))
            continue
        end
        if c > nCan
            break
        end
        token = lower(sinAcento(nombres{c}));
        if ~isempty(regexp(token, ['(^|[^a-z])' ejes{k} '([^a-z]|$)'], 'once')) ...
                || contains(token, ['f' ejes{k}]) ...
                || contains(token, ['acel' ejes{k}])
            idx(k) = c;
            usados(c) = true;
            break
        end
    end
end
if ~any(idx)
    if nCan == 1
        switch upper(ejeUnico)
            case 'Y'
                idx(2) = 1;
            case 'Z'
                idx(3) = 1;
            otherwise
                idx(1) = 1;
        end
    else
        for k = 1:min(3, nCan)
            idx(k) = k;
        end
    end
end
end

function Y = tarar(Y)
n = size(Y, 1);
nTar = min(1000, max(1, floor(0.10 * n)));
for c = 1:size(Y, 2)
    col = Y(:, c);
    if all(~isfinite(col))
        continue
    end
    base = col(1:nTar);
    base = base(isfinite(base));
    if isempty(base)
        continue
    end
    Y(:, c) = col - mean(base);
end
end

function Ys = suavizarVisual(Y, Fs)
ventana = max(1, round(0.01 * Fs));
if mod(ventana, 2) == 0
    ventana = ventana + 1;
end
Ys = Y;
for c = 1:size(Y, 2)
    col = Y(:, c);
    if all(~isfinite(col))
        continue
    end
    col(~isfinite(col)) = 0;
    Ys(:, c) = movmean(col, ventana, 'Endpoints', 'shrink');
end
end

function rms = rmsCanales(Y)
rms = nan(1, size(Y, 2));
for c = 1:size(Y, 2)
    col = Y(:, c);
    col = col(isfinite(col));
    if ~isempty(col)
        rms(c) = sqrt(mean(col.^2));
    end
end
end

function m = magnitud(Y)
m = zeros(size(Y, 1), 1);
for c = 1:size(Y, 2)
    col = Y(:, c);
    col(~isfinite(col)) = 0;
    m = m + col.^2;
end
m = sqrt(m);
end

function presentes = canalesPresentes(Y)
presentes = false(1, size(Y, 2));
for c = 1:size(Y, 2)
    presentes(c) = any(isfinite(Y(:, c)));
end
end

function [f, P] = fftCanales(Y, Fs)
f = [];
P = [];
for c = 1:size(Y, 2)
    col = Y(:, c);
    if all(~isfinite(col))
        continue
    end
    col(~isfinite(col)) = 0;
    [fc, Pc] = fftSimple(col, Fs);
    if isempty(fc)
        continue
    end
    if isempty(f)
        f = fc;
        P = nan(numel(fc), size(Y, 2));
    end
    n = min(numel(Pc), size(P, 1));
    P(1:n, c) = Pc(1:n);
end
end

function [f, P1] = fftSimple(x, Fs)
x = x(:);
x = x - mean(x(isfinite(x)));
N = numel(x);
if N < 8 || ~isfinite(Fs) || Fs <= 0
    f = [];
    P1 = [];
    return
end
n = (0:N - 1)';
ventana = 0.5 * (1 - cos(2 * pi * n / max(N - 1, 1)));
Y = fft(x .* ventana);
P2 = abs(Y / N);
mitad = floor(N / 2) + 1;
P1 = P2(1:mitad);
if numel(P1) > 2
    P1(2:end - 1) = 2 * P1(2:end - 1);
end
f = Fs * (0:mitad - 1)' / N;
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

function fn = fnRepresentativa(fnEjes)
vals = fnEjes(isfinite(fnEjes));
if isempty(vals)
    fn = NaN;
else
    fn = median(vals);
end
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

function p = plantillaPrueba()
p.nombre = '';
p.profundidad = NaN;
p.refrigerante = '';
p.herramienta = '';
p.notas = '';
p.error = '';
p.archivos = '';
p.rmsA = NaN;
p.rmsAx = NaN;
p.rmsAy = NaN;
p.rmsAz = NaN;
p.rmsFx = NaN;
p.rmsFy = NaN;
p.rmsFz = NaN;
p.rmsF = NaN;
p.fnX = NaN;
p.fnY = NaN;
p.fnZ = NaN;
p.fNatural = NaN;
p.fModal = NaN;
p.ampModal = NaN;
p.banda = [1300 1550];
p.chatter = false;
p.chatterX = false;
p.chatterY = false;
p.chatterZ = false;
p.ejeChatter = '';
p.razonCrecimiento = NaN;
p.indice = NaN;
p.nModal = 0;
p.tA = [];
p.aA = [];
p.tF = [];
p.F = [];
p.fFFT = [];
p.pFFT = [];
end

function meta = leerMeta(rel)
texto = lower(sinAcento(rel));
meta.profundidad = NaN;
token = regexp(texto, '(\d+\.?\d*)\s*mm', 'tokens', 'once');
if ~isempty(token)
    meta.profundidad = str2double(token{1});
end
if contains(texto, 'sin refrigerante')
    meta.refrigerante = 'Sin refrigerante';
elseif contains(texto, 'con refrigerante')
    meta.refrigerante = 'Con refrigerante';
else
    meta.refrigerante = '';
end
if contains(texto, 'desgastada')
    meta.herramienta = 'Desgastada';
elseif contains(texto, 'nueva')
    meta.herramienta = 'Nueva';
else
    meta.herramienta = '';
end
end

function tipo = clasificarCarpeta(nombre)
s = lower(sinAcento(strtrim(nombre)));
if any(strcmp(s, {'x', 'y', 'z'}))
    tipo = '';
    return
end
if contieneAlguna(s, {'aceleracion', 'aceleracion', 'acceleration', 'accel'})
    tipo = 'aceleracion';
elseif contieneAlguna(s, {'fuerza', 'fuerzas', 'force'})
    tipo = 'fuerza';
elseif contieneAlguna(s, {'modal', 'impacto', 'impactos'})
    tipo = 'modal';
else
    tipo = '';
end
end

function tf = contieneAlguna(s, opciones)
tf = false;
for i = 1:numel(opciones)
    if contains(s, opciones{i})
        tf = true;
        return
    end
end
end

function s = sinAcento(s)
s = char(s);
pares = {'á','a'; 'é','e'; 'í','i'; 'ó','o'; 'ú','u'; 'ñ','n'; ...
    'Á','A'; 'É','E'; 'Í','I'; 'Ó','O'; 'Ú','U'; 'Ñ','N'};
for i = 1:size(pares, 1)
    s = strrep(s, pares{i, 1}, pares{i, 2});
end
end

function rutas = listarCarpetas(raiz)
rutas = {raiz};
cola = {raiz};
while ~isempty(cola)
    actual = cola{1};
    cola(1) = [];
    d = dir(actual);
    for i = 1:numel(d)
        if ~d(i).isdir || strcmp(d(i).name, '.') || strcmp(d(i).name, '..')
            continue
        end
        sig = fullfile(actual, d(i).name);
        rutas{end + 1} = sig; %#ok<AGROW>
        cola{end + 1} = sig; %#ok<AGROW>
    end
end
end

function rel = rutasRelativa(raiz, carpeta)
raiz = char(raiz);
carpeta = char(carpeta);
if strncmpi(carpeta, raiz, numel(raiz))
    rel = carpeta(numel(raiz) + 1:end);
    if ~isempty(rel) && (rel(1) == '\' || rel(1) == '/')
        rel = rel(2:end);
    end
else
    rel = carpeta;
end
if isempty(rel)
    [~, rel] = fileparts(carpeta);
end
end

function s = marcaRuta(ruta)
if isempty(ruta)
    s = '-';
else
    [~, s] = fileparts(ruta);
end
end

function txt = redactar(pruebas)
if isempty(pruebas)
    txt = strjoin({ ...
        'Aun no hay pruebas analizadas.', ...
        '', ...
        '1. Pulsa Crear carpetas de pruebas, o elige la carpeta donde ya estan.', ...
        '2. Copia los archivos .lvm. Si estan comprimidos, descomprimelos.', ...
        '3. Aceleracion triaxial: un .lvm con tres canales, o carpetas X, Y y Z.', ...
        '4. Fuerza: un .lvm con Fx, Fy y Fz, o carpetas X, Y y Z.', ...
        '5. Modal: los impactos en la carpeta Modal.', ...
        '6. Pulsa Analizar carpetas cada vez que agregues datos.', ...
        '', ...
        'El RMS y el espectro usan la senal tarada, sin suavizar.', ...
        'La grafica de tiempo si se suaviza, solo para ver mejor la forma.', ...
        'El tiempo se reconstruye con Delta_X del archivo, no con el eje X del .lvm.', ...
        '', ...
        'Chatter: el pico dentro de la banda modal supera 4 veces la mediana del resto del espectro.', ...
        'La banda es la frecuencia natural del modal, mas o menos 125 Hz.', ...
        'Si no hay modal, la banda es 1300-1550 Hz.', ...
        'Indice mas bajo: condicion mas favorable. Vibracion 45%, pico modal 35%, fuerza 20%.'}, newline);
    return
end
lineas = {};
lineas{end + 1} = 'RESULTADO POR PRUEBA';
lineas{end + 1} = 'Un indice mas bajo indica menos vibracion, menos pico modal y menos fuerza.';
lineas{end + 1} = '';
for i = 1:numel(pruebas)
    p = pruebas(i);
    lineas{end + 1} = p.nombre; %#ok<AGROW>
    if ~isempty(p.error)
        lineas{end + 1} = ['  Error: ' p.error]; %#ok<AGROW>
        lineas{end + 1} = ''; %#ok<AGROW>
        continue
    end
    lineas{end + 1} = sprintf('  Aceleracion RMS  X %s   Y %s   Z %s g', ...
        fmt(p.rmsAx, '%.4f'), fmt(p.rmsAy, '%.4f'), fmt(p.rmsAz, '%.4f')); %#ok<AGROW>
    lineas{end + 1} = sprintf('  Fuerza RMS       X %s   Y %s   Z %s V', ...
        fmt(p.rmsFx, '%.4f'), fmt(p.rmsFy, '%.4f'), fmt(p.rmsFz, '%.4f')); %#ok<AGROW>
    lineas{end + 1} = sprintf('  Frecuencia natural  X %s   Y %s   Z %s Hz   (usada %s Hz)', ...
        fmt(p.fnX, '%.1f'), fmt(p.fnY, '%.1f'), fmt(p.fnZ, '%.1f'), fmt(p.fNatural, '%.1f')); %#ok<AGROW>
    if p.chatter
        marca = 'si';
    else
        marca = 'no';
    end
    lineas{end + 1} = sprintf('  Chatter: %s. Eje: %s. Pico %s Hz. Indice %s.', ...
        marca, p.ejeChatter, fmt(p.fModal, '%.1f'), fmt(p.indice, '%.3f')); %#ok<AGROW>
    if isfinite(p.razonCrecimiento)
        lineas{end + 1} = sprintf('  Vibracion al final / al inicio = %.2f.', p.razonCrecimiento); %#ok<AGROW>
    end
    if ~isempty(p.notas)
        lineas{end + 1} = ['  ' p.notas]; %#ok<AGROW>
    end
    lineas{end + 1} = ''; %#ok<AGROW>
end
txt = strjoin(lineas, newline);
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

function [matriz, ncols] = matrizDesdeTexto(resto, nEsperadas)
candidatos = [];
if ~isempty(nEsperadas) && isfinite(nEsperadas) && nEsperadas >= 2
    candidatos = nEsperadas;
end
candidatos = unique([candidatos, 2, 3, 4, 5, 6], 'stable');
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

function [tr, yr] = reducir(t, y, maxN)
n = size(y, 1);
t = t(:);
if n <= maxN
    tr = t;
    yr = y;
    return
end
idx = unique(round(linspace(1, n, maxN))');
tr = t(idx);
yr = y(idx, :);
end

function [f2, p2] = reducirEspectro(f, P)
if isempty(f)
    f2 = [];
    p2 = [];
    return
end
mask = f <= 4000;
f = f(mask);
P = P(mask, :);
if size(f, 1) <= 2500
    f2 = f;
    p2 = P;
    return
end
pico = max(P, [], 2);
pico(~isfinite(pico)) = -inf;
[~, ip] = max(pico);
idx = unique([round(linspace(1, numel(f), 2500))'; ip]);
f2 = f(idx);
p2 = P(idx, :);
end

function m = maxFin(v)
v = v(isfinite(v));
if isempty(v)
    m = NaN;
else
    m = max(v);
end
end

function [h, y] = uiTexto(parent, y, txt, alto)
fondo = get(parent, 'BackgroundColor');
h = uicontrol('Parent', parent, 'Style', 'text', 'String', txt, ...
    'Units', 'normalized', 'Position', [0.04, y - alto, 0.92, alto], ...
    'HorizontalAlignment', 'left', 'BackgroundColor', fondo, 'FontSize', 9);
y = y - alto - 0.004;
end

function [h, y] = uiEdit(parent, y, cadena, alto)
h = uicontrol('Parent', parent, 'Style', 'edit', 'String', cadena, ...
    'Units', 'normalized', 'Position', [0.04, y - alto, 0.92, alto], ...
    'HorizontalAlignment', 'left', 'BackgroundColor', 'white', 'FontSize', 9);
y = y - alto - 0.008;
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
    'FontSize', 10, 'Callback', cb);
y = y - alto - 0.008;
end

function ax = crearEjes(parent, pos)
ax = axes('Parent', parent, 'Units', 'normalized', 'Position', pos, 'FontSize', 9);
set(ax, 'TickLabelInterpreter', 'none');
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

function s = fmt(v, spec)
if isempty(v) || ~isscalar(v) || ~isfinite(v)
    s = '-';
else
    s = sprintf(spec, v);
end
end

function s = csvNum(v)
if isempty(v) || ~isscalar(v) || ~isfinite(v)
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
v = strrep(v, newline, ' ');
s = ['"' v '"'];
end

function c = coloresEjes()
c = [0.15 0.35 0.75; 0.80 0.25 0.20; 0.10 0.55 0.30];
end

function txt = valorPopup(h)
items = get(h, 'String');
txt = items{get(h, 'Value')};
end
