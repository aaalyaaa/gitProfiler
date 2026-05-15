## Создание встроенной базы данных-примера для пакета gitProfiler
## ============================================================================
##
## Этот скрипт выполняет полный ETL-пайплайн для реального Git-репозитория,
## обогащает данные аналитическими метриками и сохраняет готовую базу данных
## в папку inst/extdata/ пакета. Пользователи пакета смогут подключиться к
## этой базе через функцию example_db() и сразу приступить к анализу без
## необходимости самостоятельно загружать репозиторий.
##
## Что делает скрипт:
##   1. Клонирует репозиторий dbipAnalyzer (R-пакет для анализа данных об
##      автономных системах) с GitHub во временную папку.
##   2. Запускает ETL-пайплайн: извлекает историю коммитов и построчные
##      изменения кода, сохраняет их в DuckDB.
##   3. Вычисляет метрики разработчиков (активность, размер коммитов,
##      используемые языки программирования).
##   4. Кэширует аномалии (ночные коммиты, коммиты в выходные, большие
##      коммиты, ML-аномалии через Isolation Forest).
##   5. Классифицирует коммиты по типам (feat, fix, docs, refactor, test и др.)
##      с использованием предобученной модели randomForest.
##   6. Сохраняет готовую базу в пакет и удаляет временные файлы.
##
## Запуск:
##   source("data-raw/make_example_db.R")
##
## Результат:
##   Файл inst/extdata/git_example.duckdb (пример базы данных)
##
## Примечания:
##   - Для работы требуется доступ в интернет (клонирование репозитория)
##   - Скрипт занимает 1-2 минуты в зависимости от скорости соединения
##   - При повторном запуске база будет пересоздана с актуальными данными
##   - После создания базы необходимо пересобрать пакет:
##       devtools::install()
##
## ============================================================================

library(gitProfiler)

example_repo_url <- "https://github.com/aaalyaaa/dbipAnalyzer.git"
temp_clone_dir <- tempdir()

result <- run_etl_pipeline(
  mode = 1,
  repo_url = example_repo_url,
  clone_dir = temp_clone_dir
)

if (result$status == "success") {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = "git.duckdb")

  message("Building developer metrics...")
  refresh_developer_metrics(con)

  message("Caching anomalies...")
  cache_anomalies(con)

  message("Classifying commits...")
  model <- load_commit_model()
  classify_commits_in_db(con, model)

  DBI::dbDisconnect(con, shutdown = TRUE)

  dir.create("inst/extdata", recursive = TRUE, showWarnings = FALSE)
  file.copy("git.duckdb", "inst/extdata/git_example.duckdb", overwrite = TRUE)
  file.remove("git.duckdb")

  message("Example database created at inst/extdata/git_example.duckdb")
  message("Repository: ", example_repo_url)
  message("Commits loaded: ", result$message)
} else {
  message("Failed to create example database: ", result$message)
}
