%% ================================================================
%  PROCESAMIENTO DE DATOS DE TORNEADO
%  Fuerza + Aceleración
%
%  Pruebas:
%       - 0.5 mm
%       - 1.0 mm
%
%  Características:
%       - Selección manual de carpetas
%       - Lectura robusta de archivos .lvm
%       - Concatenación de archivos
%       - Tarado global por prueba
%       - Suavizado fuerte para visualización
%       - Reducción de puntos para graficar
%       - Conservación de datos originales
%       - Conservación de datos tarados
%       - Gráficas individuales y comparativas
%       - Guardado automático en .mat
%
%  IMPORTANTE:
%  El suavizado fuerte se utiliza para VISUALIZACIÓN.
%  Los datos originales y tarados se conservan para FFT/PSD/chatter.
% ================================================================

clear;
clc;
close all;

%% ================================================================
%                  CONFIGURACIÓN GENERAL
% ================================================================

% Número de muestras utilizadas para calcular el tarado.
% Se toma del INICIO DE LA PRUEBA completa.
N_tarado = 1000;

% Ventana de suavizado fuerte
%
% Aceleración:
%   101 muestras
%
% Fuerza:
%   151 muestras
%
% Como la frecuencia de muestreo es aproximadamente:
%   Fuerza       = 3000 Hz
%   Aceleración  = 10240 Hz
%
% estas ventanas producen un suavizado apreciable.
ventana_fuerza = 151;
ventana_aceleracion = 101;

% Número máximo de puntos utilizados únicamente para las gráficas.
% Esto NO modifica los datos guardados.
max_puntos_grafica = 15000;

% ¿Mostrar comparación entre señal original y suavizada?
mostrar_comparacion = true;

%% ================================================================
%                    SELECCIÓN DE CARPETAS
% ================================================================

fprintf('\n=============================================\n');
fprintf('   PROCESAMIENTO DE DATOS DE TORNEADO\n');
fprintf('=============================================\n\n');

%% ---------------- ACELERACIÓN ----------------

fprintf('Seleccione la carpeta raíz de ACELERACIÓN.\n');

carpetaA_raiz = uigetdir(pwd, ...
    'Seleccione la carpeta raíz de ACELERACIÓN');

if carpetaA_raiz == 0
    error('No se seleccionó la carpeta de aceleración.');
end

fprintf('\nSeleccione la carpeta de ACELERACIÓN - Prueba 0.5 mm.\n');

carpetaA_05 = uigetdir(carpetaA_raiz, ...
    'Seleccione ACELERACIÓN - Prueba 0.5 mm');

if carpetaA_05 == 0
    error('No se seleccionó la carpeta de aceleración de 0.5 mm.');
end

fprintf('\nSeleccione la carpeta de ACELERACIÓN - Prueba 1 mm.\n');

carpetaA_10 = uigetdir(carpetaA_raiz, ...
    'Seleccione ACELERACIÓN - Prueba 1 mm');

if carpetaA_10 == 0
    error('No se seleccionó la carpeta de aceleración de 1 mm.');
end

%% ---------------- FUERZA ----------------

fprintf('\nSeleccione la carpeta raíz de FUERZA.\n');

carpetaF_raiz = uigetdir(pwd, ...
    'Seleccione la carpeta raíz de FUERZA');

if carpetaF_raiz == 0
    error('No se seleccionó la carpeta de fuerza.');
end

fprintf('\nSeleccione la carpeta de FUERZA - Prueba 0.5 mm.\n');

carpetaF_05 = uigetdir(carpetaF_raiz, ...
    'Seleccione FUERZA - Prueba 0.5 mm');

if carpetaF_05 == 0
    error('No se seleccionó la carpeta de fuerza de 0.5 mm.');
end

fprintf('\nSeleccione la carpeta de FUERZA - Prueba 1 mm.\n');

carpetaF_10 = uigetdir(carpetaF_raiz, ...
    'Seleccione FUERZA - Prueba 1 mm');

if carpetaF_10 == 0
    error('No se seleccionó la carpeta de fuerza de 1 mm.');
end


%% ================================================================
%                 PROCESAMIENTO 0.5 mm
% ================================================================

fprintf('\n=============================================\n');
fprintf('        PROCESANDO PRUEBA 0.5 mm\n');
fprintf('=============================================\n');

[A05, At05, FsA05, offsetA05, A05_original] = ...
    procesarAceleracion( ...
    carpetaA_05, ...
    N_tarado, ...
    ventana_aceleracion, ...
    max_puntos_grafica);

[F05, Ft05, FsF05, offsetF05, F05_original] = ...
    procesarFuerza( ...
    carpetaF_05, ...
    N_tarado, ...
    ventana_fuerza, ...
    max_puntos_grafica);


%% ================================================================
%                 PROCESAMIENTO 1 mm
% ================================================================

fprintf('\n=============================================\n');
fprintf('        PROCESANDO PRUEBA 1 mm\n');
fprintf('=============================================\n');

[A10, At10, FsA10, offsetA10, A10_original] = ...
    procesarAceleracion( ...
    carpetaA_10, ...
    N_tarado, ...
    ventana_aceleracion, ...
    max_puntos_grafica);

[F10, Ft10, FsF10, offsetF10, F10_original] = ...
    procesarFuerza( ...
    carpetaF_10, ...
    N_tarado, ...
    ventana_fuerza, ...
    max_puntos_grafica);


%% ================================================================
%                       INFORMACIÓN
% ================================================================

fprintf('\n=============================================\n');
fprintf('              INFORMACIÓN\n');
fprintf('=============================================\n\n');

fprintf('Prueba 0.5 mm:\n');
fprintf('  Fs aceleración = %.2f Hz\n', FsA05);
fprintf('  Fs fuerza      = %.2f Hz\n', FsF05);

fprintf('\nPrueba 1 mm:\n');
fprintf('  Fs aceleración = %.2f Hz\n', FsA10);
fprintf('  Fs fuerza      = %.2f Hz\n', FsF10);

fprintf('\nTarado aceleración:\n');
fprintf('  0.5 mm = %.6f g\n', offsetA05);
fprintf('  1.0 mm = %.6f g\n', offsetA10);

fprintf('\nTarado fuerza:\n');
fprintf('  0.5 mm:\n');
fprintf('      Fx = %.6f V\n', offsetF05(1));
fprintf('      Fy = %.6f V\n', offsetF05(2));
fprintf('      Fz = %.6f V\n', offsetF05(3));

fprintf('\n  1.0 mm:\n');
fprintf('      Fx = %.6f V\n', offsetF10(1));
fprintf('      Fy = %.6f V\n', offsetF10(2));
fprintf('      Fz = %.6f V\n', offsetF10(3));


%% ================================================================
%                 GRÁFICA FUERZA - 0.5 mm
% ================================================================

figure('Name','Fuerza suavizada - Prueba 0.5 mm',...
    'Color','w');

plot(Ft05, F05(:,1), 'LineWidth', 1.2);
hold on;

plot(Ft05, F05(:,2), 'LineWidth', 1.2);
plot(Ft05, F05(:,3), 'LineWidth', 1.2);

grid on;
box on;

xlabel('Tiempo [s]');
ylabel('Voltaje tarado [V]');

title('Fuerza suavizada - Prueba 0.5 mm');

legend('F_x','F_y','F_z',...
    'Location','best');

set(gca,'FontSize',11);


%% ================================================================
%                 GRÁFICA FUERZA - 1 mm
% ================================================================

figure('Name','Fuerza suavizada - Prueba 1 mm',...
    'Color','w');

plot(Ft10, F10(:,1), 'LineWidth', 1.2);
hold on;

plot(Ft10, F10(:,2), 'LineWidth', 1.2);
plot(Ft10, F10(:,3), 'LineWidth', 1.2);

grid on;
box on;

xlabel('Tiempo [s]');
ylabel('Voltaje tarado [V]');

title('Fuerza suavizada - Prueba 1 mm');

legend('F_x','F_y','F_z',...
    'Location','best');

set(gca,'FontSize',11);


%% ================================================================
%             GRÁFICA ACELERACIÓN - 0.5 mm
% ================================================================

figure('Name','Aceleración suavizada - Prueba 0.5 mm',...
    'Color','w');

plot(At05, A05, 'LineWidth', 1.2);

grid on;
box on;

xlabel('Tiempo [s]');
ylabel('Aceleración tarada [g]');

title('Aceleración suavizada - Prueba 0.5 mm');

set(gca,'FontSize',11);


%% ================================================================
%             GRÁFICA ACELERACIÓN - 1 mm
% ================================================================

figure('Name','Aceleración suavizada - Prueba 1 mm',...
    'Color','w');

plot(At10, A10, 'LineWidth', 1.2);

grid on;
box on;

xlabel('Tiempo [s]');
ylabel('Aceleración tarada [g]');

title('Aceleración suavizada - Prueba 1 mm');

set(gca,'FontSize',11);


%% ================================================================
%                  COMPARACIÓN DE FUERZAS
% ================================================================

figure('Name','Comparación de fuerzas',...
    'Color','w');

% Fx
subplot(3,1,1);

plot(Ft05,F05(:,1),'LineWidth',1.1);
hold on;
plot(Ft10,F10(:,1),'LineWidth',1.1);

grid on;
box on;

ylabel('F_x [V]');
title('Comparación F_x');

legend('0.5 mm','1 mm',...
    'Location','best');

% Fy
subplot(3,1,2);

plot(Ft05,F05(:,2),'LineWidth',1.1);
hold on;
plot(Ft10,F10(:,2),'LineWidth',1.1);

grid on;
box on;

ylabel('F_y [V]');
title('Comparación F_y');

legend('0.5 mm','1 mm',...
    'Location','best');

% Fz
subplot(3,1,3);

plot(Ft05,F05(:,3),'LineWidth',1.1);
hold on;
plot(Ft10,F10(:,3),'LineWidth',1.1);

grid on;
box on;

xlabel('Tiempo [s]');
ylabel('F_z [V]');
title('Comparación F_z');

legend('0.5 mm','1 mm',...
    'Location','best');


%% ================================================================
%             COMPARACIÓN DE ACELERACIÓN
% ================================================================

figure('Name','Comparación de aceleración',...
    'Color','w');

plot(At05,A05,'LineWidth',1.1);
hold on;

plot(At10,A10,'LineWidth',1.1);

grid on;
box on;

xlabel('Tiempo [s]');
ylabel('Aceleración [g]');

title('Comparación de aceleración');

legend('0.5 mm','1 mm',...
    'Location','best');

set(gca,'FontSize',11);


%% ================================================================
%        COMPARACIÓN ORIGINAL VS SUAVIZADA - FUERZA
% ================================================================

if mostrar_comparacion

    figure('Name','Comparación original vs suavizada',...
        'Color','w');

    % Tomar una ventana inicial para no saturar la pantalla
    Nmostrar = min(length(F05), round(10*FsF05));

    tiempo_original = (0:Nmostrar-1)'/FsF05;

    subplot(3,1,1);

    plot(tiempo_original,...
        F05_original(1:Nmostrar,1),...
        'LineWidth',0.7);

    hold on;

    plot(tiempo_original,...
        F05(1:Nmostrar,1),...
        'LineWidth',1.5);

    grid on;
    box on;

    ylabel('F_x [V]');
    title('F_x: original vs suavizada');

    legend('Original','Suavizada');


    subplot(3,1,2);

    plot(tiempo_original,...
        F05_original(1:Nmostrar,2),...
        'LineWidth',0.7);

    hold on;

    plot(tiempo_original,...
        F05(1:Nmostrar,2),...
        'LineWidth',1.5);

    grid on;
    box on;

    ylabel('F_y [V]');
    title('F_y: original vs suavizada');

    legend('Original','Suavizada');


    subplot(3,1,3);

    plot(tiempo_original,...
        F05_original(1:Nmostrar,3),...
        'LineWidth',0.7);

    hold on;

    plot(tiempo_original,...
        F05(1:Nmostrar,3),...
        'LineWidth',1.5);

    grid on;
    box on;

    xlabel('Tiempo [s]');
    ylabel('F_z [V]');
    title('F_z: original vs suavizada');

    legend('Original','Suavizada');

end


%% ================================================================
%                  GUARDAR RESULTADOS
% ================================================================

fprintf('\nGuardando resultados...\n');

Datos_Torneado = struct();

%% ---------------- 0.5 mm ----------------

Datos_Torneado.Prueba_05mm.Aceleracion = A05;
Datos_Torneado.Prueba_05mm.Aceleracion_t = At05;
Datos_Torneado.Prueba_05mm.Fs_Aceleracion = FsA05;

Datos_Torneado.Prueba_05mm.Fuerza = F05;
Datos_Torneado.Prueba_05mm.Fuerza_t = Ft05;
Datos_Torneado.Prueba_05mm.Fs_Fuerza = FsF05;

Datos_Torneado.Prueba_05mm.Aceleracion_Original = A05_original;
Datos_Torneado.Prueba_05mm.Fuerza_Original = F05_original;

Datos_Torneado.Prueba_05mm.Tarado_Aceleracion = offsetA05;
Datos_Torneado.Prueba_05mm.Tarado_Fuerza = offsetF05;


%% ---------------- 1 mm ----------------

Datos_Torneado.Prueba_10mm.Aceleracion = A10;
Datos_Torneado.Prueba_10mm.Aceleracion_t = At10;
Datos_Torneado.Prueba_10mm.Fs_Aceleracion = FsA10;

Datos_Torneado.Prueba_10mm.Fuerza = F10;
Datos_Torneado.Prueba_10mm.Fuerza_t = Ft10;
Datos_Torneado.Prueba_10mm.Fs_Fuerza = FsF10;

Datos_Torneado.Prueba_10mm.Aceleracion_Original = A10_original;
Datos_Torneado.Prueba_10mm.Fuerza_Original = F10_original;

Datos_Torneado.Prueba_10mm.Tarado_Aceleracion = offsetA10;
Datos_Torneado.Prueba_10mm.Tarado_Fuerza = offsetF10;


%% ---------------- CONFIGURACIÓN ----------------

Datos_Torneado.Configuracion.N_tarado = N_tarado;

Datos_Torneado.Configuracion.Ventana_Fuerza = ...
    ventana_fuerza;

Datos_Torneado.Configuracion.Ventana_Aceleracion = ...
    ventana_aceleracion;

Datos_Torneado.Configuracion.Max_puntos_grafica = ...
    max_puntos_grafica;

Datos_Torneado.Configuracion.Descripcion = ...
    'Datos concatenados, tarados globalmente y suavizados para visualizacion.';


%% ---------------- GUARDAR ----------------

save('Datos_Torneado_Procesados.mat',...
    'Datos_Torneado',...
    '-v7.3');

fprintf('\n=============================================\n');
fprintf('        PROCESAMIENTO TERMINADO\n');
fprintf('=============================================\n');

fprintf('\nArchivo generado:\n');
fprintf('Datos_Torneado_Procesados.mat\n\n');


%% ================================================================
%                  FUNCIÓN ACELERACIÓN
% ================================================================

function [senal_suavizada, tiempo, Fs, offset, senal_original] = ...
    procesarAceleracion(carpeta,N_tarado,ventana,max_puntos)

    fprintf('\nProcesando aceleración...\n');

    archivos = dir(fullfile(carpeta,'A*.lvm'));

    if isempty(archivos)
        error('No se encontraron archivos A*.lvm en:\n%s',carpeta);
    end

    %% Ordenar archivos numéricamente

    numeros = nan(length(archivos),1);

    for i = 1:length(archivos)

        nombre = archivos(i).name;

        token = regexp(nombre,...
            '^A_+(\d+)(?:\(\d+\))?\.lvm$',...
            'tokens','once');

        if ~isempty(token)
            numeros(i) = str2double(token{1});
        end
    end

    [~,orden] = sort(numeros);

    archivos = archivos(orden);


    %% Leer y concatenar

    senal_original = [];

    Fs_lista = [];

    for i = 1:length(archivos)

        nombre = fullfile(carpeta,archivos(i).name);

        fprintf('  Leyendo: %s\n',archivos(i).name);

        [t,Y,Fs_archivo] = leerLVM(nombre);

        if isempty(Y)
            warning('Archivo vacío: %s',archivos(i).name);
            continue;
        end

        senal_original = [senal_original; Y(:,1)];

        Fs_lista(end+1) = Fs_archivo;

    end


    %% Frecuencia de muestreo

    Fs = median(Fs_lista);

    fprintf('  Frecuencia de muestreo: %.2f Hz\n',Fs);


    %% ============================================================
    %                     TARADO GLOBAL
    % =============================================================

    N = min(N_tarado,length(senal_original));

    offset = mean(senal_original(1:N));

    fprintf('  Tarado global = %.6f g\n',offset);

    senal_tarada = senal_original - offset;


    %% ============================================================
    %                     SUAVIZADO
    % =============================================================

    fprintf('  Aplicando suavizado de %d muestras...\n',ventana);

    % Primer suavizado
    senal_suavizada = movmean(...
        senal_tarada,...
        ventana,...
        'Endpoints','shrink');

    % Segundo suavizado ligero para eliminar
    % oscilaciones visuales restantes
    ventana2 = round(ventana/2);

    senal_suavizada = movmean(...
        senal_suavizada,...
        ventana2,...
        'Endpoints','shrink');


    %% ============================================================
    %                  REDUCCIÓN PARA GRÁFICA
    % =============================================================

    Ntotal = length(senal_suavizada);

    if Ntotal > max_puntos

        factor = ceil(Ntotal/max_puntos);

        indices = 1:factor:Ntotal;

        senal_suavizada = senal_suavizada(indices);

        tiempo = (indices-1)'/Fs;

    else

        tiempo = (0:Ntotal-1)'/Fs;

    end

end


%% ================================================================
%                     FUNCIÓN FUERZA
% ================================================================

function [senal_suavizada, tiempo, Fs, offset, senal_original] = ...
    procesarFuerza(carpeta,N_tarado,ventana,max_puntos)

    fprintf('\nProcesando fuerza...\n');

    archivos = dir(fullfile(carpeta,'F*.lvm'));

    if isempty(archivos)
        error('No se encontraron archivos F*.lvm en:\n%s',carpeta);
    end


    %% Ordenar archivos numéricamente

    numeros = nan(length(archivos),1);

    for i = 1:length(archivos)

        nombre = archivos(i).name;

        token = regexp(nombre,...
            '^F_+(\d+)(?:\(\d+\))?\.lvm$',...
            'tokens','once');

        if ~isempty(token)
            numeros(i) = str2double(token{1});
        end

    end

    [~,orden] = sort(numeros);

    archivos = archivos(orden);


    %% Leer y concatenar

    senal_original = [];

    Fs_lista = [];

    for i = 1:length(archivos)

        nombre = fullfile(carpeta,archivos(i).name);

        fprintf('  Leyendo: %s\n',archivos(i).name);

        [t,Y,Fs_archivo] = leerLVM(nombre);

        if isempty(Y)
            warning('Archivo vacío: %s',archivos(i).name);
            continue;
        end

        % Verificar que existan los tres canales
        if size(Y,2) < 3
            error('El archivo %s no contiene tres canales de fuerza.',...
                archivos(i).name);
        end

        senal_original = [senal_original; Y(:,1:3)];

        Fs_lista(end+1) = Fs_archivo;

    end


    %% Frecuencia de muestreo

    Fs = median(Fs_lista);

    fprintf('  Frecuencia de muestreo: %.2f Hz\n',Fs);


    %% ============================================================
    %                     TARADO GLOBAL
    % =============================================================

    N = min(N_tarado,size(senal_original,1));

    offset = mean(senal_original(1:N,:),1);

    fprintf('\n  Tarado global:\n');

    fprintf('      Fx = %.6f V\n',offset(1));
    fprintf('      Fy = %.6f V\n',offset(2));
    fprintf('      Fz = %.6f V\n',offset(3));

    senal_tarada = senal_original - offset;


    %% ============================================================
    %                     SUAVIZADO
    % ============================================================

    fprintf('  Aplicando suavizado de %d muestras...\n',ventana);

    senal_suavizada = zeros(size(senal_tarada));

    for canal = 1:3

        % Primer suavizado
        temp = movmean(...
            senal_tarada(:,canal),...
            ventana,...
            'Endpoints','shrink');

        % Segundo suavizado
        ventana2 = round(ventana/2);

        senal_suavizada(:,canal) = movmean(...
            temp,...
            ventana2,...
            'Endpoints','shrink');

    end


    %% ============================================================
    %                  REDUCCIÓN PARA GRÁFICA
    % =============================================================

    Ntotal = size(senal_suavizada,1);

    if Ntotal > max_puntos

        factor = ceil(Ntotal/max_puntos);

        indices = 1:factor:Ntotal;

        senal_suavizada = senal_suavizada(indices,:);

        tiempo = (indices-1)'/Fs;

    else

        tiempo = (0:Ntotal-1)'/Fs;

    end

end


%% ================================================================
%                     FUNCIÓN PARA LEER LVM
% ================================================================

function [t,Y,Fs] = leerLVM(nombreArchivo)

    fid = fopen(nombreArchivo,'r');

    if fid == -1
        error('No se pudo abrir el archivo:\n%s',nombreArchivo);
    end

    %% Variables

    Delta_X = [];

    encabezadoEncontrado = false;

    %% Buscar información del encabezado

    while ~feof(fid)

        linea = fgetl(fid);

        if ~ischar(linea)
            continue;
        end

        linea = strtrim(linea);


        % Delta_X
        if startsWith(linea,'Delta_X')

            partes = strsplit(linea,sprintf('\t'));

            valores = [];

            for k = 2:length(partes)

                valor = str2double(strtrim(partes{k}));

                if ~isnan(valor)
                    valores(end+1) = valor;
                end

            end

            if ~isempty(valores)
                Delta_X = valores;
            end

        end


        % Buscar encabezado de datos
        if startsWith(linea,'X_Value')

            encabezadoEncontrado = true;
            break;

        end

    end


    %% Verificación

    if ~encabezadoEncontrado
        fclose(fid);
        error('No se encontró la línea X_Value en:\n%s',...
            nombreArchivo);
    end


    %% Leer datos

    datos = [];

    while ~feof(fid)

        linea = fgetl(fid);

        if ~ischar(linea)
            continue;
        end

        linea = strtrim(linea);

        if isempty(linea)
            continue;
        end


        partes = strsplit(linea,sprintf('\t'));

        valores = nan(1,length(partes));

        for k = 1:length(partes)

            valores(k) = str2double(...
                strtrim(partes{k}));

        end


        % Se requiere al menos tiempo + un canal
        if length(valores) >= 2 && ...
                ~isnan(valores(1))

            datos(end+1,1:length(valores)) = valores;

        end

    end

    fclose(fid);


    %% Verificar datos

    if isempty(datos)

        error('No se encontraron datos numéricos en:\n%s',...
            nombreArchivo);

    end


    %% Tiempo

    t = datos(:,1);

    %% Señales

    Y = datos(:,2:end);


    %% Frecuencia de muestreo

    if ~isempty(Delta_X)

        Delta = median(Delta_X);

    else

        diferencias = diff(t);

        diferencias = diferencias(...
            diferencias > 0 & ...
            diferencias < 1);

        Delta = median(diferencias);

    end


    Fs = 1/Delta;

end