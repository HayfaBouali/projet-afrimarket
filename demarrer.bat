@echo off
rem === Dossier du projet : calculé automatiquement (dossier de ce script) ===
set "PROJET=%~dp0"
set "PROJET=%PROJET:~0,-1%"

rem === Dossier de la plateforme : la SEULE ligne à adapter si besoin ===
set "LAKEHOUSE=%PROJET%\..\lakehouse"

rem === Dossiers du projet branchés dans les conteneurs (Airflow, spark-submit) ===
set "DAGS_DIR=%PROJET%\dags"
set "JOBS_DIR=%PROJET%\jobs"

echo Plateforme : %LAKEHOUSE%
echo Projet     : %PROJET%

rem Images construites une fois avec : docker compose build (dans le dossier lakehouse)
rem Ajouter --profile ml après "compose" pour démarrer aussi MLflow
docker compose --project-directory "%LAKEHOUSE%" -f "%LAKEHOUSE%\docker-compose.yml" --env-file "%LAKEHOUSE%\.env" up -d

pause