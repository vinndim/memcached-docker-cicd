# --- ЭТАП 1: Сборка (Build Stage) ---
# Используем стабильный образ Debian для компиляции
FROM debian:bookworm-slim AS builder

# Передаем опции конфигурации
ARG CONFIGURE_OPTS="--enable-seccomp"

# Устанавливаем зависимости, необходимые ТОЛЬКО для сборки (build-time)
RUN apt-get update && apt-get install -y \
    build-essential \
    automake \
    autoconf \
    libevent-dev \
    libseccomp-dev \
    git \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Копируем исходный код
WORKDIR /build-src
COPY . .

# Процесс сборки legacy-приложения на C
RUN ./autogen.sh && \
    ./configure ${CONFIGURE_OPTS} && \
    make -j$(nproc)

# --- ЭТАП 2: Финальный образ (Runtime Stage) ---
# Начинаем с чистого листа. Здесь не будет компилятора GCC и исходников.
FROM debian:bookworm-slim

# Устанавливаем ТОЛЬКО библиотеки, необходимые для работы (runtime)
# libevent и libseccomp нужны бинарнику для запуска
RUN apt-get update && apt-get install -y \
    libevent-2.1-7 \
    libseccomp2 \
    && rm -rf /var/lib/apt/lists/*

# Создаем системного пользователя без домашней директории для безопасности
RUN useradd -r -s /sbin/nologin memcached

# Копируем только готовый бинарный файл из первого этапа
COPY --from=builder /build-src/memcached /usr/local/bin/memcached

# Указываем пользователя, от которого будет работать сервис
USER memcached

# Порт по умолчанию для Memcached
EXPOSE 11211

# Запуск приложения
ENTRYPOINT ["memcached"]