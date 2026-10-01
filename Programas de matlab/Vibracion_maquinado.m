%% ================================================================
%  ANALISIS DE VIBRACION DURANTE MAQUINADO
%
%  Autor: 
%
%  FUNCIONES:
%  1. Seleccion de carpetas para diferentes pruebas
%  2. Lectura de archivos A__1.lvm, A__2.lvm, ...
%  3. Concatenacion de archivos
%  4. Reconstruccion correcta del eje temporal
%  5. Grafica de aceleracion vs tiempo
%  6. Calculo de RMS
%  7. FFT individual
%  8. Comparacion de FFT
%  9. Analisis de banda modal 1.3-1.55 kHz
%
%  IMPORTANTE:
%  El eje X original de los archivos LVM puede presentar saltos
%  entre bloques. Por eso el tiempo se reconstruye utilizando
%  Delta_X del encabezado.
%
%  No requiere Signal Processing Toolbox.
% ================================================================
 
clear
clc
close all
 
 
%% ================================================================
% 1. PARAMETROS DEL ANALISIS
% ================================================================
 
% ------------------------------------------------
% Banda donde esperamos encontrar el modo
% estructural identificado mediante impacto
% ------------------------------------------------
 
f_modal_min = 1300;       % Hz
f_modal_max = 1550;       % Hz
 
% ------------------------------------------------
% Frecuencia minima para mostrar en FFT
% ------------------------------------------------
 
f_fft_min = 0;
 
% ------------------------------------------------
% Eliminar componente DC
% ------------------------------------------------
 
quitar_media = true;
 
 
%% ================================================================
% 2. PREGUNTAR NUMERO DE PRUEBAS
% ================================================================
 
num_pruebas = input( ...
    '¿Cuantas pruebas deseas comparar? ');
 
if isempty(num_pruebas) || num_pruebas < 1
 
    error( ...
        'El numero de pruebas debe ser mayor o igual a 1.');
 
end
 
 
%% ================================================================
% 3. SELECCIONAR CARPETA DE CADA PRUEBA
% ================================================================
 
datos = struct();
 
for p = 1:num_pruebas
 
    fprintf('\n');
    fprintf('================================================\n');
    fprintf('SELECCION DE CARPETA - PRUEBA %d\n',p);
    fprintf('================================================\n');
 
    carpeta = uigetdir( ...
        pwd, ...
        sprintf('Selecciona la carpeta de la prueba %d',p));
 
    % ------------------------------------------------
    % Verificar seleccion
    % ------------------------------------------------
 
    if isequal(carpeta,0)
 
        error( ...
            'No se selecciono una carpeta para la prueba %d.',p);
 
    end
 
    datos(p).carpeta = carpeta;
 
 
    %% ------------------------------------------------------------
    % Buscar archivos A__*.lvm
    % ------------------------------------------------------------
 
    archivos = dir( ...
        fullfile(carpeta,'A__*.lvm'));
 
    % ------------------------------------------------
    % Intentar extension mayuscula
    % ------------------------------------------------
 
    if isempty(archivos)
 
        archivos = dir( ...
            fullfile(carpeta,'A__*.LVM'));
 
    end
 
 
    %% ------------------------------------------------------------
    % Verificar que existan archivos
    % ------------------------------------------------------------
 
    if isempty(archivos)
 
        error([ ...
            'No se encontraron archivos A__*.lvm en:\n%s\n\n' ...
            'Verifica el nombre de los archivos.'], ...
            carpeta);
 
    end
 
 
    %% ------------------------------------------------------------
    % Ordenar archivos numericamente
    % ------------------------------------------------------------
 
    nombres = {archivos.name};
 
    numeros = nan(length(nombres),1);
 
    for k = 1:length(nombres)
 
        nombre = nombres{k};
 
        % Buscar numero despues de A__
        token = regexp( ...
            nombre, ...
            'A__([0-9]+)', ...
            'tokens', ...
            'once');
 
        if ~isempty(token)
 
            numeros(k) = ...
                str2double(token{1});
 
        end
 
    end
 
    % Orden numerico
    [~,orden] = sort(numeros);
 
    archivos = archivos(orden);
 
 
    %% ------------------------------------------------------------
    % Mostrar archivos encontrados
    % ------------------------------------------------------------
 
    fprintf('\nArchivos encontrados para la prueba %d:\n',p);
 
    for k = 1:length(archivos)
 
        fprintf('   %s\n', ...
            archivos(k).name);
 
    end
 
 
    %% ============================================================
    % 4. LEER Y CONCATENAR TODOS LOS ARCHIVOS
    % ============================================================
 
    aceleracion_total = [];
 
    Fs_prueba = [];
 
 
    for k = 1:length(archivos)
 
        archivo_actual = ...
            fullfile( ...
                carpeta, ...
                archivos(k).name);
 
        fprintf('\nLeyendo: %s\n', ...
            archivos(k).name);
 
 
        %% --------------------------------------------------------
        % Leer archivo
        % --------------------------------------------------------
 
        [~,a,Fs] = ...
            leer_LVM(archivo_actual);
 
 
        %% --------------------------------------------------------
        % Guardar frecuencia de muestreo
        % --------------------------------------------------------
 
        if isempty(Fs_prueba)
 
            Fs_prueba = Fs;
 
        else
 
            % Verificar que todos tengan el mismo Fs
 
            if abs(Fs-Fs_prueba) > 1
 
                warning([ ...
                    'La frecuencia de muestreo cambia entre ' ...
                    'archivos de la prueba %d.'],p);
 
            end
 
        end
 
 
        %% --------------------------------------------------------
        % Concatenar aceleracion
        % --------------------------------------------------------
 
        aceleracion_total = ...
            [aceleracion_total; a];
 
    end
 
 
    %% ============================================================
    % 5. RECONSTRUIR EJE TEMPORAL CONTINUO
    % ============================================================
 
    N_total = ...
        length(aceleracion_total);
 
    tiempo_total = ...
        (0:N_total-1)'/Fs_prueba;
 
 
    %% ============================================================
    % 6. GUARDAR DATOS DE LA PRUEBA
    % ============================================================
 
    datos(p).t = tiempo_total;
 
    datos(p).a = aceleracion_total;
 
    datos(p).Fs = Fs_prueba;
 
    datos(p).N = N_total;
 
    datos(p).duracion = ...
        tiempo_total(end);
 
 
    %% ============================================================
    % 7. INFORMACION DE LA PRUEBA
    % ============================================================
 
    fprintf('\n');
    fprintf('--------------------------------------------\n');
    fprintf('INFORMACION PRUEBA %d\n',p);
    fprintf('--------------------------------------------\n');
 
    fprintf('Numero de archivos = %d\n', ...
        length(archivos));
 
    fprintf('Numero de muestras = %d\n', ...
        N_total);
 
    fprintf('Frecuencia de muestreo = %.2f Hz\n', ...
        Fs_prueba);
 
    fprintf('Frecuencia Nyquist = %.2f Hz\n', ...
        Fs_prueba/2);
 
    fprintf('Duracion total = %.3f s\n', ...
        tiempo_total(end));
 
end
 
 
%% ================================================================
% 8. GRAFICA DE VIBRACION
% ================================================================
 
figure( ...
    'Name','Vibracion durante el maquinado', ...
    'NumberTitle','off', ...
    'Color','w');
 
 
for p = 1:num_pruebas
 
    subplot(num_pruebas,1,p);
 
 
    plot( ...
        datos(p).t, ...
        datos(p).a, ...
        'b');
 
 
    grid on;
 
 
    xlabel('Tiempo [s]');
 
    ylabel('Aceleracion [g]');
 
 
    title( ...
        sprintf( ...
        'Prueba %d - Vibracion durante maquinado', ...
        p), ...
        'FontWeight','bold');
 
 
end
 
 
%% ================================================================
% 9. CALCULO RMS
% ================================================================
 
RMS = zeros(num_pruebas,1);
 
 
for p = 1:num_pruebas
 
    a = datos(p).a;
 
 
    % ------------------------------------------------
    % Eliminar componente DC
    % ------------------------------------------------
 
    if quitar_media
 
        a = ...
            a - mean(a);
 
    end
 
 
    % ------------------------------------------------
    % RMS
    % ------------------------------------------------
 
    RMS(p) = ...
        sqrt(mean(a.^2));
 
end
 
 
%% ================================================================
% 10. GRAFICA DE RMS
% ================================================================
 
figure( ...
    'Name','RMS de vibracion', ...
    'NumberTitle','off', ...
    'Color','w');
 
 
bar(RMS);
 
 
grid on;
 
 
xlabel('Prueba');
 
ylabel('RMS [g]');
 
 
title( ...
    'RMS de vibracion durante el maquinado', ...
    'FontWeight','bold');
 
 
xticks(1:num_pruebas);
 
 
%% ------------------------------------------------
% Colocar valor encima de cada barra
% ------------------------------------------------
 
for p = 1:num_pruebas
 
    text( ...
        p, ...
        RMS(p), ...
        sprintf(' %.4f g',RMS(p)), ...
        'HorizontalAlignment','center', ...
        'VerticalAlignment','bottom', ...
        'FontWeight','bold');
 
end
 
 
%% ================================================================
% 11. CALCULAR FFT DE CADA PRUEBA
% ================================================================
 
resultadosFFT = struct();
 
 
for p = 1:num_pruebas
 
    %% ------------------------------------------------------------
    % Datos
    % ------------------------------------------------------------
 
    a = datos(p).a;
 
    Fs = datos(p).Fs;
 
 
    %% ------------------------------------------------------------
    % Eliminar componente DC
    % ------------------------------------------------------------
 
    if quitar_media
 
        a = ...
            a - mean(a);
 
    end
 
 
    %% ------------------------------------------------------------
    % Numero de muestras
    % ------------------------------------------------------------
 
    N = length(a);
 
 
    %% ------------------------------------------------------------
    % Ventana Hann
    % ------------------------------------------------------------
 
    n = (0:N-1)';
 
 
    ventana = ...
        0.5 * ...
        (1-cos(2*pi*n/(N-1)));
 
 
    a_ventana = ...
        a .* ventana;
 
 
    %% ------------------------------------------------------------
    % FFT
    % ------------------------------------------------------------
 
    Y = fft(a_ventana);
 
 
    P2 = ...
        abs(Y/N);
 
 
    P1 = ...
        P2(1:floor(N/2)+1);
 
 
    % Duplicar amplitud
    % excepto DC y Nyquist
 
    if length(P1) > 2
 
        P1(2:end-1) = ...
            2*P1(2:end-1);
 
    end
 
 
    %% ------------------------------------------------------------
    % Vector de frecuencias
    % ------------------------------------------------------------
 
    f = ...
        Fs*(0:floor(N/2))/N;
 
 
    %% ------------------------------------------------------------
    % Guardar
    % ------------------------------------------------------------
 
    resultadosFFT(p).f = f;
 
    resultadosFFT(p).P1 = P1;
 
 
    %% ============================================================
    % 12. BUSCAR PICO EN BANDA MODAL
    % ============================================================
 
    indices_modal = ...
        f >= f_modal_min & ...
        f <= f_modal_max;
 
 
    if any(indices_modal)
 
        f_modal = ...
            f(indices_modal);
 
        A_modal = ...
            P1(indices_modal);
 
 
        % Maximo dentro de la banda
 
        [amplitud_modal,indice_max] = ...
            max(A_modal);
 
 
        frecuencia_modal = ...
            f_modal(indice_max);
 
    else
 
        frecuencia_modal = NaN;
 
        amplitud_modal = NaN;
 
    end
 
 
    %% ------------------------------------------------------------
    % Guardar resultados
    % ------------------------------------------------------------
 
    resultadosFFT(p).frecuencia_modal = ...
        frecuencia_modal;
 
    resultadosFFT(p).amplitud_modal = ...
        amplitud_modal;
 
end
 
 
%% ================================================================
% 13. FFT INDIVIDUAL
% ================================================================
 
for p = 1:num_pruebas
 
    f = ...
        resultadosFFT(p).f;
 
    P1 = ...
        resultadosFFT(p).P1;
 
    Fs = ...
        datos(p).Fs;
 
 
    %% ------------------------------------------------------------
    % Crear figura
    % ------------------------------------------------------------
 
    figure( ...
        'Name', ...
        sprintf('FFT - Prueba %d',p), ...
        'NumberTitle','off', ...
        'Color','w');
 
 
    %% ------------------------------------------------------------
    % FFT
    % ------------------------------------------------------------
 
    plot( ...
        f, ...
        P1, ...
        'b', ...
        'LineWidth',1);
 
 
    hold on;
 
    grid on;
 
 
    %% ------------------------------------------------------------
    % Banda modal
    % ------------------------------------------------------------
 
    xline( ...
        f_modal_min, ...
        '--r', ...
        '1300 Hz');
 
 
    xline( ...
        f_modal_max, ...
        '--r', ...
        '1550 Hz');
 
 
    %% ------------------------------------------------------------
    % Pico modal encontrado
    % ------------------------------------------------------------
 
    fm = ...
        resultadosFFT(p).frecuencia_modal;
 
    Am = ...
        resultadosFFT(p).amplitud_modal;
 
 
    if ~isnan(fm)
 
        plot( ...
            fm, ...
            Am, ...
            'ro', ...
            'MarkerFaceColor','r');
 
 
        text( ...
            fm, ...
            Am, ...
            sprintf('  %.1f Hz',fm), ...
            'VerticalAlignment','bottom', ...
            'FontWeight','bold');
 
    end
 
 
    %% ------------------------------------------------------------
    % Etiquetas
    % ------------------------------------------------------------
 
    xlabel('Frecuencia [Hz]');
 
    ylabel('Amplitud [g]');
 
 
    title( ...
        sprintf('FFT - Prueba %d',p), ...
        'FontWeight','bold');
 
 
    %% ------------------------------------------------------------
    % Limites
    % ------------------------------------------------------------
 
    xlim([ ...
        f_fft_min ...
        Fs/2]);
 
 
end
 
 
%% ================================================================
% 14. COMPARACION DE TODOS LOS FFT
% ================================================================
 
figure( ...
    'Name','Comparacion FFT', ...
    'NumberTitle','off', ...
    'Color','w');
 
 
hold on;
 
 
for p = 1:num_pruebas
 
    plot( ...
        resultadosFFT(p).f, ...
        resultadosFFT(p).P1, ...
        'LineWidth',1);
 
end
 
 
grid on;
 
 
xlabel('Frecuencia [Hz]');
 
ylabel('Amplitud [g]');
 
 
title( ...
    'Comparacion de espectros', ...
    'FontWeight','bold');
 
 
%% ------------------------------------------------
% Limite de frecuencia
% ------------------------------------------------
 
Fs_min = ...
    min([datos.Fs]);
 
 
xlim([ ...
    f_fft_min ...
    Fs_min/2]);
 
 
%% ------------------------------------------------
% Leyenda
% ------------------------------------------------
 
legendStrings = ...
    cell(num_pruebas,1);
 
 
for p = 1:num_pruebas
 
    legendStrings{p} = ...
        sprintf('Prueba %d',p);
 
end
 
 
legend( ...
    legendStrings, ...
    'Location','best');
 
 
%% ================================================================
% 15. COMPARACION DE LA BANDA MODAL
% ================================================================
 
frecuencias_modal = ...
    zeros(num_pruebas,1);
 
 
amplitudes_modal = ...
    zeros(num_pruebas,1);
 
 
for p = 1:num_pruebas
 
    frecuencias_modal(p) = ...
        resultadosFFT(p).frecuencia_modal;
 
    amplitudes_modal(p) = ...
        resultadosFFT(p).amplitud_modal;
 
end
 
 
%% ================================================================
% 16. GRAFICA DE AMPLITUD MODAL
% ================================================================
 
figure( ...
    'Name','Respuesta alrededor de frecuencia modal', ...
    'NumberTitle','off', ...
    'Color','w');
 
 
bar(amplitudes_modal);
 
 
grid on;
 
 
xlabel('Prueba');
 
ylabel('Amplitud espectral [g]');
 
 
title( ...
    sprintf( ...
    'Amplitud maxima en banda modal %.0f-%.0f Hz', ...
    f_modal_min, ...
    f_modal_max), ...
    'FontWeight','bold');
 
 
xticks(1:num_pruebas);
 
 
%% ------------------------------------------------
% Valores sobre barras
% ------------------------------------------------
 
for p = 1:num_pruebas
 
    text( ...
        p, ...
        amplitudes_modal(p), ...
        sprintf(' %.5f g', ...
        amplitudes_modal(p)), ...
        'HorizontalAlignment','center', ...
        'VerticalAlignment','bottom', ...
        'FontWeight','bold');
 
end
 
 
%% ================================================================
% 17. RESUMEN EN COMMAND WINDOW
% ================================================================
 
fprintf('\n\n');
 
fprintf('============================================================\n');
 
fprintf('             RESUMEN DEL ANALISIS DE VIBRACION\n');
 
fprintf('============================================================\n\n');
 
 
fprintf( ...
    '%10s %15s %15s %18s %18s\n', ...
    'Prueba', ...
    'Fs [Hz]', ...
    'RMS [g]', ...
    'Pico modal [Hz]', ...
    'Amplitud [g]');
 
 
fprintf( ...
    '%10s %15s %15s %18s %18s\n', ...
    '------', ...
    '-------', ...
    '-------', ...
    '--------------', ...
    '------------');
 
 
for p = 1:num_pruebas
 
    fprintf( ...
        '%10d %15.2f %15.5f %18.2f %18.6f\n', ...
        p, ...
        datos(p).Fs, ...
        RMS(p), ...
        frecuencias_modal(p), ...
        amplitudes_modal(p));
 
end
 
 
fprintf('\n');
 
fprintf('Banda modal analizada: %.0f - %.0f Hz\n', ...
    f_modal_min, ...
    f_modal_max);
 
 
fprintf('\n============================================================\n');
 
 
%% ================================================================
% 18. FUNCION PARA LEER ARCHIVOS LVM
% ================================================================
 
function [t,a,Fs] = leer_LVM(nombre_archivo)
 
    %% ------------------------------------------------------------
    % Abrir archivo
    % ------------------------------------------------------------
 
    fid = ...
        fopen(nombre_archivo,'r');
 
 
    if fid == -1
 
        error( ...
            'No se pudo abrir el archivo: %s', ...
            nombre_archivo);
 
    end
 
 
    %% ------------------------------------------------------------
    % Variables del encabezado
    % ------------------------------------------------------------
 
    Delta_X = [];
 
    contador_header = 0;
 
 
    %% ============================================================
    % Leer encabezado
    % ============================================================
 
    while ~feof(fid)
 
        linea = ...
            fgetl(fid);
 
 
        %% --------------------------------------------------------
        % Buscar Delta_X
        % --------------------------------------------------------
 
        if contains(linea,'Delta_X')
 
            partes = ...
                strsplit(linea,'\t');
 
 
            if length(partes) >= 2
 
                Delta_X = ...
                    str2double(partes{2});
 
            end
 
        end
 
 
        %% --------------------------------------------------------
        % Contar End_of_Header
        % --------------------------------------------------------
 
        if contains( ...
                linea, ...
                '***End_of_Header***')
 
            contador_header = ...
                contador_header + 1;
 
 
            if contador_header == 2
 
                break
 
            end
 
        end
 
    end
 
 
    %% ============================================================
    % Saltar encabezado de columnas
    % ============================================================
 
    fgetl(fid);
 
 
    %% ============================================================
    % Leer datos
    % ============================================================
 
    datos_leidos = ...
        textscan( ...
            fid, ...
            '%f%f', ...
            'Delimiter','\t', ...
            'CollectOutput',true);
 
 
    %% ------------------------------------------------------------
    % Cerrar archivo
    % ------------------------------------------------------------
 
    fclose(fid);
 
 
    %% ============================================================
    % Verificar datos
    % ============================================================
 
    if isempty(datos_leidos) || ...
       isempty(datos_leidos{1})
 
        error( ...
            'No se encontraron datos en %s', ...
            nombre_archivo);
 
    end
 
 
    %% ------------------------------------------------------------
    % Matriz de datos
    % ------------------------------------------------------------
 
    matriz = ...
        datos_leidos{1};
 
 
    %% ------------------------------------------------------------
    % Aceleracion
    % ------------------------------------------------------------
 
    a = ...
        matriz(:,2);
 
 
    %% ============================================================
    % Verificar Delta_X
    % ============================================================
 
    if isempty(Delta_X) || ...
       isnan(Delta_X)
 
        error([ ...
            'No se pudo encontrar Delta_X en %s'], ...
            nombre_archivo);
 
    end
 
 
    %% ============================================================
    % Frecuencia de muestreo
    % ============================================================
 
    Fs = ...
        1/Delta_X;
 
 
    %% ============================================================
    % Reconstruir tiempo
    % ============================================================
 
    N = ...
        length(a);
 
 
    t = ...
        (0:N-1)'/Fs;
 
end