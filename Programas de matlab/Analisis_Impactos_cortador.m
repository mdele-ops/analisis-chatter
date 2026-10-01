%% ============================================================
% ANALISIS DE IMPACTOS DEL CORTADOR
%
% 6 impactos originales
% Se elimina el impacto 2 por ruido
% Se analizan los impactos:
%
%       1 - 3 - 4 - 5 - 6
%
% NO REQUIERE SIGNAL PROCESSING TOOLBOX
%
% ============================================================
 
clear
clc
close all
 
 
%% ============================================================
% 1. PARAMETROS
% ============================================================
 
numero_impactos = 6;
 
ensayo_eliminar = 2;
 
tiempo_pre = 0.02;          % [s]
 
duracion_prueba = 1.0;      % [s]
 
% Rango de frecuencia que queremos estudiar
fmin_analisis = 20;         % [Hz]
fmax = 3000;                % [Hz]
 
% Distancia minima entre impactos
distancia_minima = 0.03;   % [s]
 
% Umbral de deteccion
umbral_porcentaje = 0.15;
 
 
%% ============================================================
% 2. SELECCIONAR CARPETA
% ============================================================
 
carpeta = uigetdir( ...
    pwd, ...
    'Selecciona la carpeta donde estan los archivos A_1 y A_2');
 
 
if isequal(carpeta,0)
 
    error('No se selecciono ninguna carpeta.');
 
end
 
 
%% ============================================================
% 3. BUSCAR ARCHIVOS
% ============================================================
 
archivo_A1_lista = dir( ...
    fullfile(carpeta,'A_1*.lvm'));
 
 
archivo_A2_lista = dir( ...
    fullfile(carpeta,'A_2*.lvm'));
 
 
if isempty(archivo_A1_lista)
 
    error('No se encontro A_1*.lvm');
 
end
 
 
if isempty(archivo_A2_lista)
 
    error('No se encontro A_2*.lvm');
 
end
 
 
archivo_A1 = fullfile( ...
    carpeta, ...
    archivo_A1_lista(1).name);
 
 
archivo_A2 = fullfile( ...
    carpeta, ...
    archivo_A2_lista(1).name);
 
 
fprintf('\n');
fprintf('A_1 = %s\n',archivo_A1);
 
fprintf('A_2 = %s\n',archivo_A2);
 
 
%% ============================================================
% 4. LEER ARCHIVOS
% ============================================================
 
[A1,t1,Fs1] = leer_LVM(archivo_A1);
 
[A2,t2,Fs2] = leer_LVM(archivo_A2);
 
 
if abs(Fs1-Fs2) > 1e-6
 
    error('A_1 y A_2 tienen diferente Fs.');
 
end
 
 
Fs = Fs1;
 
 
fprintf('\n');
fprintf('Frecuencia de muestreo = %.2f Hz\n',Fs);
 
 
%% ============================================================
% 5. CONCATENAR
% ============================================================
 
A = [A1; A2];
 
N = length(A);
 
t = (0:N-1)'/Fs;
 
 
fprintf('Numero total de datos = %d\n',N);
 
fprintf('Duracion total = %.3f s\n',N/Fs);
 
 
%% ============================================================
% 6. ELIMINAR OFFSET
% ============================================================
 
A = A - mean(A);
 
 
%% ============================================================
% 7. GRAFICA DE LA SEÑAL COMPLETA
% ============================================================
 
figure('Color','w');
 
plot(t,A);
 
grid on;
 
xlabel('Tiempo [s]');
ylabel('Aceleracion [g]');
 
title('Señal completa');
 
 
%% ============================================================
% 8. ENVOLVENTE
% ============================================================
 
envolvente = abs(A);
 
 
ventana_suavizado = ...
    round(0.005*Fs);
 
 
envolvente_suave = ...
    movmean(envolvente,ventana_suavizado);
 
 
%% ============================================================
% 9. UMBRAL
% ============================================================
 
umbral = ...
    umbral_porcentaje * ...
    max(envolvente_suave);
 
 
%% ============================================================
% 10. DETECCION DE IMPACTOS
% ============================================================
 
distancia_muestras = ...
    round(distancia_minima*Fs);
 
 
radio_local = ...
    round(0.005*Fs);
 
 
candidatos_locs = [];
 
candidatos_picos = [];
 
 
for i = radio_local+1:N-radio_local
 
 
    valor = envolvente_suave(i);
 
 
    if valor < umbral
 
        continue
 
    end
 
 
    vecindario = ...
        envolvente_suave( ...
        i-radio_local:i+radio_local);
 
 
    if valor == max(vecindario)
 
 
        candidatos_locs(end+1,1) = i;
 
        candidatos_picos(end+1,1) = valor;
 
 
    end
 
end
 
 
%% ============================================================
% 11. ORDENAR POR AMPLITUD
% ============================================================
 
[~,orden] = ...
    sort(candidatos_picos,'descend');
 
 
candidatos_locs = ...
    candidatos_locs(orden);
 
 
candidatos_picos = ...
    candidatos_picos(orden);
 
 
%% ============================================================
% 12. SELECCIONAR 6 IMPACTOS
% ============================================================
 
locs = [];
 
picos = [];
 
 
for i = 1:length(candidatos_locs)
 
 
    candidato = candidatos_locs(i);
 
    candidato_pico = candidatos_picos(i);
 
 
    if isempty(locs)
 
 
        locs(end+1,1) = candidato;
 
        picos(end+1,1) = candidato_pico;
 
 
    else
 
 
        distancias = ...
            abs(candidato-locs);
 
 
        if all(distancias >= distancia_muestras)
 
 
            locs(end+1,1) = candidato;
 
            picos(end+1,1) = candidato_pico;
 
 
        end
 
    end
 
 
    if length(locs) == numero_impactos
 
        break
 
    end
 
end
 
 
%% ============================================================
% 13. ORDEN CRONOLOGICO
% ============================================================
 
[locs,orden] = sort(locs);
 
picos = picos(orden);
 
 
%% ============================================================
% 14. MOSTRAR IMPACTOS
% ============================================================
 
fprintf('\n');
fprintf('====================================================\n');
fprintf('IMPACTOS DETECTADOS\n');
fprintf('====================================================\n');
 
 
for i = 1:length(locs)
 
    fprintf( ...
        'Impacto %d --> %.4f s   %.4f g\n', ...
        i, ...
        t(locs(i)), ...
        picos(i));
 
end
 
 
if length(locs) ~= numero_impactos
 
    error( ...
        'No se detectaron exactamente 6 impactos.');
 
end
 
 
%% ============================================================
% 15. GRAFICA DE IMPACTOS
% ============================================================
 
figure('Color','w');
 
plot(t,A);
 
hold on;
 
plot( ...
    t(locs), ...
    A(locs), ...
    'ro', ...
    'MarkerFaceColor','r');
 
 
for i = 1:length(locs)
 
    text( ...
        t(locs(i)), ...
        A(locs(i)), ...
        sprintf('  %d',i), ...
        'FontWeight','bold');
 
end
 
 
grid on;
 
xlabel('Tiempo [s]');
ylabel('Aceleracion [g]');
 
title('Impactos detectados');
 
 
%% ============================================================
% 16. ELIMINAR ENSAYO 2
% ============================================================
 
ensayos_validos = ...
    setdiff(1:numero_impactos,ensayo_eliminar);
 
 
locs_validos = ...
    locs(ensayos_validos);
 
 
fprintf('\n');
fprintf('====================================================\n');
fprintf('ENSAYOS UTILIZADOS\n');
fprintf('====================================================\n');
 
 
fprintf( ...
    'Ensayos: %s\n', ...
    mat2str(ensayos_validos));
 
 
%% ============================================================
% 17. EXTRAER RESPUESTAS
% ============================================================
 
numero_ensayos = ...
    length(ensayos_validos);
 
 
muestras_pre = ...
    round(tiempo_pre*Fs);
 
 
muestras_totales = ...
    round(duracion_prueba*Fs);
 
 
pruebas = cell(numero_ensayos,1);
 
tiempos_pruebas = cell(numero_ensayos,1);
 
 
for i = 1:numero_ensayos
 
 
    indice_original = ...
        ensayos_validos(i);
 
 
    posicion = ...
        locs(indice_original);
 
 
    inicio = ...
        posicion - muestras_pre;
 
 
    final = ...
        inicio + muestras_totales - 1;
 
 
    inicio = max(inicio,1);
 
    final = min(final,N);
 
 
    pruebas{i} = ...
        A(inicio:final);
 
 
    tiempos_pruebas{i} = ...
        (0:length(pruebas{i})-1)'/Fs;
 
 
end
 
 
%% ============================================================
% 18. RESPUESTAS TEMPORALES
% ============================================================
 
figure('Color','w');
 
 
for i = 1:numero_ensayos
 
 
    subplot(numero_ensayos,1,i);
 
 
    plot( ...
        tiempos_pruebas{i}, ...
        pruebas{i});
 
 
    grid on;
 
 
    ylabel( ...
        sprintf('%d [g]',ensayos_validos(i)));
 
 
    title( ...
        sprintf('Impacto original %d', ...
        ensayos_validos(i)));
 
 
    if i == numero_ensayos
 
        xlabel('Tiempo [s]');
 
    end
 
end
 
 
sgtitle('Respuestas temporales');
 
 
%% ============================================================
% 19. FFT DE LOS 5 ENSAYOS
% ============================================================
 
frec = cell(numero_ensayos,1);
 
amp = cell(numero_ensayos,1);
 
frecuencia_principal = ...
    nan(numero_ensayos,1);
 
amplitud_principal = ...
    nan(numero_ensayos,1);
 
 
figure('Color','w');
 
 
for i = 1:numero_ensayos
 
 
    %% --------------------------------------------------------
    % Señal
    % ---------------------------------------------------------
 
    x = pruebas{i};
 
 
    x = x - mean(x);
 
 
    L = length(x);
 
 
    %% --------------------------------------------------------
    % Ventana Hann
    % ---------------------------------------------------------
 
    n = (0:L-1)';
 
 
    ventana = ...
        0.5*(1-cos(2*pi*n/(L-1)));
 
 
    x = x .* ventana;
 
 
    %% --------------------------------------------------------
    % FFT
    % ---------------------------------------------------------
 
    Y = fft(x);
 
 
    P2 = abs(Y/L);
 
 
    P1 = ...
        P2(1:floor(L/2)+1);
 
 
    if length(P1) > 2
 
        P1(2:end-1) = ...
            2*P1(2:end-1);
 
    end
 
 
    f = ...
        Fs*(0:floor(L/2))/L;
 
 
    frec{i} = f;
 
    amp{i} = P1;
 
 
    %% --------------------------------------------------------
    % Rango de frecuencia
    % ---------------------------------------------------------
 
    indices = ...
        f >= fmin_analisis & ...
        f <= fmax;
 
 
    f2 = f(indices);
 
    P2 = P1(indices);
 
 
    %% --------------------------------------------------------
    % BUSCAR MAXIMOS LOCALES
    % ---------------------------------------------------------
 
    candidatos_f = [];
 
    candidatos_a = [];
 
 
    for j = 2:length(P2)-1
 
 
        if P2(j) > P2(j-1) && ...
           P2(j) >= P2(j+1)
 
 
            candidatos_f(end+1) = f2(j);
 
            candidatos_a(end+1) = P2(j);
 
 
        end
 
    end
 
 
    %% --------------------------------------------------------
    % SI NO HAY MAXIMOS LOCALES
    % ---------------------------------------------------------
 
    if isempty(candidatos_a)
 
 
        [valor,pos] = max(P2);
 
 
        frecuencia_principal(i) = f2(pos);
 
        amplitud_principal(i) = valor;
 
 
    else
 
 
        %% ----------------------------------------------------
        % Ordenar por amplitud
        % -----------------------------------------------------
 
        [~,orden] = ...
            sort(candidatos_a,'descend');
 
 
        candidatos_f = ...
            candidatos_f(orden);
 
 
        candidatos_a = ...
            candidatos_a(orden);
 
 
        %% ----------------------------------------------------
        % Guardar el mayor
        % -----------------------------------------------------
 
        frecuencia_principal(i) = ...
            candidatos_f(1);
 
 
        amplitud_principal(i) = ...
            candidatos_a(1);
 
    end
 
 
    %% --------------------------------------------------------
    % GRAFICA INDIVIDUAL
    % ---------------------------------------------------------
 
    subplot(numero_ensayos,1,i);
 
 
    plot(f2,P2);
 
 
    hold on;
 
 
    plot( ...
        frecuencia_principal(i), ...
        amplitud_principal(i), ...
        'ro', ...
        'MarkerFaceColor','r');
 
 
    grid on;
 
 
    xlim([fmin_analisis fmax]);
 
 
    % IMPORTANTE:
    % El eje Y se adapta automaticamente a cada ensayo
 
 
    ylabel('g');
 
 
    title( ...
        sprintf( ...
        'Impacto %d | Dominante = %.1f Hz', ...
        ensayos_validos(i), ...
        frecuencia_principal(i)));
 
 
    if i == numero_ensayos
 
        xlabel('Frecuencia [Hz]');
 
    end
 
end
 
 
sgtitle('FFT individual de los 5 ensayos');
 
 
%% ============================================================
% 20. IMPRIMIR RESULTADOS
% ============================================================
 
fprintf('\n');
fprintf('====================================================\n');
fprintf('FRECUENCIAS DOMINANTES\n');
fprintf('====================================================\n');
 
 
fprintf('\n');
 
 
for i = 1:numero_ensayos
 
 
    fprintf( ...
        'Impacto original %d --> %.2f Hz   %.6f g\n', ...
        ensayos_validos(i), ...
        frecuencia_principal(i), ...
        amplitud_principal(i));
 
 
end
 
 
%% ============================================================
% 21. FFT NORMALIZADA
%
% Esta grafica es especialmente importante.
%
% Cada espectro se divide entre su propio maximo.
%
% Por lo tanto:
%
%       amplitud maxima = 1
%
% Esto permite comparar FACILMENTE la posicion de los picos
% aunque los impactos hayan tenido diferente intensidad.
%
% ============================================================
 
figure('Color','w');
 
 
hold on;
 
 
for i = 1:numero_ensayos
 
 
    f = frec{i};
 
    P = amp{i};
 
 
    indices = ...
        f >= fmin_analisis & ...
        f <= fmax;
 
 
    f2 = f(indices);
 
    P2 = P(indices);
 
 
    % Normalizar
 
    Pnorm = ...
        P2/max(P2);
 
 
    plot( ...
        f2, ...
        Pnorm, ...
        'DisplayName', ...
        sprintf('Impacto %d', ...
        ensayos_validos(i)));
 
 
end
 
 
grid on;
 
 
xlabel('Frecuencia [Hz]');
 
ylabel('Amplitud normalizada');
 
 
title( ...
    'Comparacion normalizada de los 5 espectros');
 
 
legend( ...
    'Location','best');
 
 
xlim([fmin_analisis fmax]);
 
ylim([0 1.05]);
 
 
%% ============================================================
% 22. GRAFICA DE LAS FRECUENCIAS DOMINANTES
% ============================================================
 
figure('Color','w');
 
 
plot( ...
    ensayos_validos, ...
    frecuencia_principal, ...
    'o-');
 
 
grid on;
 
 
xlabel('Numero de impacto');
 
ylabel('Frecuencia dominante [Hz]');
 
 
title( ...
    'Frecuencia dominante de los ensayos');
 
 
xlim([0.5 numero_impactos+0.5]);
 
 
%% ============================================================
% 23. ESTADISTICA
% ============================================================
 
frecuencia_promedio = ...
    mean(frecuencia_principal);
 
 
desviacion_frecuencia = ...
    std(frecuencia_principal);
 
 
variacion_relativa = ...
    100*desviacion_frecuencia/ ...
    frecuencia_promedio;
 
 
fprintf('\n');
fprintf('====================================================\n');
fprintf('ESTADISTICA\n');
fprintf('====================================================\n');
 
 
fprintf( ...
    'Frecuencia promedio = %.2f Hz\n', ...
    frecuencia_promedio);
 
 
fprintf( ...
    'Desviacion estandar = %.2f Hz\n', ...
    desviacion_frecuencia);
 
 
fprintf( ...
    'Variacion relativa = %.2f %%\n', ...
    variacion_relativa);
 
 
fprintf('\n');
fprintf('Analisis terminado.\n');
 
 
%% ============================================================
% FUNCION PARA LEER LVM
% ============================================================
 
function [datos,tiempo,Fs] = leer_LVM(nombre_archivo)
 
 
    fid = fopen( ...
        nombre_archivo, ...
        'r');
 
 
    if fid == -1
 
        error( ...
            'No se pudo abrir: %s', ...
            nombre_archivo);
 
    end
 
 
    contenido = ...
        textscan( ...
        fid, ...
        '%s', ...
        'Delimiter','\n', ...
        'Whitespace','');
 
 
    fclose(fid);
 
 
    lineas = contenido{1};
 
 
    %% --------------------------------------------------------
    % Delta_X
    % ---------------------------------------------------------
 
    deltaX = NaN;
 
 
    for i = 1:length(lineas)
 
 
        if contains( ...
                lineas{i}, ...
                'Delta_X')
 
 
            partes = ...
                strsplit( ...
                lineas{i}, ...
                '\t');
 
 
            if length(partes) >= 2
 
                deltaX = ...
                    str2double( ...
                    strtrim(partes{2}));
 
            end
 
 
            break
 
        end
 
    end
 
 
    if isnan(deltaX)
 
        error( ...
            'No se encontro Delta_X.');
 
    end
 
 
    Fs = 1/deltaX;
 
 
    %% --------------------------------------------------------
    % Buscar X_Value
    % ---------------------------------------------------------
 
    indice_datos = [];
 
 
    for i = 1:length(lineas)
 
 
        linea = strtrim(lineas{i});
 
 
        if startsWith( ...
                linea, ...
                'X_Value')
 
 
            indice_datos = i+1;
 
            break
 
        end
 
    end
 
 
    if isempty(indice_datos)
 
        error( ...
            'No se encontro X_Value.');
 
    end
 
 
    %% --------------------------------------------------------
    % Leer datos
    % ---------------------------------------------------------
 
    datos = [];
 
    tiempo = [];
 
 
    for i = indice_datos:length(lineas)
 
 
        linea = ...
            strtrim(lineas{i});
 
 
        if isempty(linea)
 
            continue
 
        end
 
 
        partes = ...
            strsplit( ...
            linea, ...
            '\t');
 
 
        if length(partes) >= 2
 
 
            t = ...
                str2double( ...
                strtrim(partes{1}));
 
 
            a = ...
                str2double( ...
                strtrim(partes{2}));
 
 
            if ~isnan(t) && ~isnan(a)
 
 
                tiempo(end+1,1) = t;
 
                datos(end+1,1) = a;
 
 
            end
 
        end
 
    end
 
 
    if isempty(datos)
 
        error( ...
            'No se encontraron datos en %s', ...
            nombre_archivo);
 
    end
 
end