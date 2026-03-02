-- ============================================================
--  BON VOYAGE — Database Schema
--  PostgreSQL
-- ============================================================

-- Extensión para UUIDs
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
--  MÓDULO DE USUARIOS
-- ============================================================

CREATE TABLE users (
    user_id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email           VARCHAR(255) NOT NULL UNIQUE,
    password_hash   VARCHAR(255),                          -- NULL si auth_provider = 'google'
    google_id       VARCHAR(255) UNIQUE,                   -- NULL si auth_provider = 'local'
    auth_provider   VARCHAR(10) NOT NULL DEFAULT 'local'
                        CHECK (auth_provider IN ('local', 'google')),
    first_name      VARCHAR(255) NOT NULL,
    last_name        VARCHAR(255) NOT NULL,
    profile_picture_url TEXT,
    status          VARCHAR(20) NOT NULL DEFAULT 'active'
                        CHECK (status IN ('active', 'inactive', 'suspended')),
    created_at      TIMESTAMP NOT NULL DEFAULT NOW(),
    last_login      TIMESTAMP,

    -- Garantiza que local tenga contraseña y google tenga google_id
    CONSTRAINT chk_local_auth  CHECK (auth_provider <> 'local'  OR password_hash IS NOT NULL),
    CONSTRAINT chk_google_auth CHECK (auth_provider <> 'google' OR google_id IS NOT NULL)
);

-- -------------------------------------------------------

--CREATE TABLE user_preferences (
--    preference_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
--    user_id             UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
--    budget_range        JSONB,          -- { "min": 50, "max": 200 } por día
--    dietary_restrictions JSONB,         -- ["vegetariano", "sin gluten"]
--    interests           JSONB,          -- ["cultura", "aventura", "gastronomía"]
--    preferred_currency  VARCHAR(10) DEFAULT 'USD',
--    preferred_language  VARCHAR(5)  DEFAULT 'es',
--    email_preferences   JSONB,          -- { draft_reminder: true, trip_upcoming: true }
--    updated_at          TIMESTAMP NOT NULL DEFAULT NOW(),

--    UNIQUE (user_id)
--);

-- -------------------------------------------------------

CREATE TABLE user_travel_history (
    history_id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    trip_id         UUID,               -- referencia lógica, sin FK estricta (viaje ya completado)
    destination     VARCHAR(255) NOT NULL,
    country         VARCHAR(100) NOT NULL,
    travel_date     DATE,
    created_at      TIMESTAMP NOT NULL DEFAULT NOW()
);

-- ============================================================
--  MÓDULO DE WISHLIST
-- ============================================================

CREATE TABLE wishlist (
    wishlist_id     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    country         VARCHAR(100) NOT NULL,
    city            VARCHAR(150) NOT NULL,
    created_at      TIMESTAMP NOT NULL DEFAULT NOW(),

    UNIQUE (user_id, country, city)     -- evita duplicados por usuario
);

-- ============================================================
--  MÓDULO DE DESTINOS
-- ============================================================

CREATE TABLE destinations (
    destination_id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name                VARCHAR(255) NOT NULL,
    country             VARCHAR(100) NOT NULL,
    city                VARCHAR(150) NOT NULL,
    latitude            DECIMAL(10, 7) NOT NULL,
    longitude           DECIMAL(10, 7) NOT NULL,
    timezone            VARCHAR(60),
    currency_code       VARCHAR(10),
    popular_months      JSONB,          -- [6, 7, 8, 12]
    image_url           TEXT,
    created_at          TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMP NOT NULL DEFAULT NOW()
);

-- -------------------------------------------------------

CREATE TABLE flight_price_trends (
    trend_id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    destination_id      UUID NOT NULL REFERENCES destinations(destination_id) ON DELETE CASCADE,
    origin_airport_code VARCHAR(10) NOT NULL,
    month               SMALLINT NOT NULL CHECK (month BETWEEN 1 AND 12),
    avg_price           DECIMAL(10, 2),
    min_price           DECIMAL(10, 2),
    currency            VARCHAR(10) DEFAULT 'USD',
    last_updated        TIMESTAMP NOT NULL DEFAULT NOW()
);

-- ============================================================
--  MÓDULO DE ITINERARIOS
-- ============================================================

CREATE TABLE trips (
    trip_id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    destination_id  UUID REFERENCES destinations(destination_id)
    start_date      DATE NOT NULL,
    end_date        DATE NOT NULL,
    status          VARCHAR(20) NOT NULL DEFAULT 'draft'
                        CHECK (status IN ('draft', 'confirmed', 'completed', 'cancelled')),
    total_budget    DECIMAL(12, 2),
    currency        VARCHAR(10) DEFAULT 'USD',
    is_favorite     BOOLEAN NOT NULL DEFAULT FALSE,   -- múltiples viajes pueden ser favoritos
    confirmed_at    TIMESTAMP,
    created_at      TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMP NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_dates CHECK (end_date >= start_date),
    CONSTRAINT chk_max_days CHECK ((end_date - start_date) <= 30)
);

-- -------------------------------------------------------

CREATE TABLE itinerary_days (
    day_id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id         UUID NOT NULL REFERENCES trips(trip_id) ON DELETE CASCADE,
    day_date        DATE NOT NULL,
    day_number      SMALLINT NOT NULL,      -- 1, 2, 3...
    notes           TEXT,
    created_at      TIMESTAMP NOT NULL DEFAULT NOW(),

    UNIQUE (trip_id, day_number),
    UNIQUE (trip_id, day_date)
);

-- -------------------------------------------------------

CREATE TABLE itinerary_items (
    item_id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    day_id                  UUID NOT NULL REFERENCES itinerary_days(day_id) ON DELETE CASCADE,

    -- Tipo de ítem expandido para cubrir todos los casos
    item_type               VARCHAR(30) NOT NULL
                                CHECK (item_type IN (
                                    'flight_outbound',      -- vuelo de ida
                                    'flight_return',        -- vuelo de vuelta
                                    'hotel',                -- hospedaje (info de rango de fechas)
                                    'restaurant',
                                    'poi',
                                    'essential_service'
                                )),

    external_reference_id   VARCHAR(255),   -- ID en tabla de referencias correspondiente
    item_data               JSONB NOT NULL, -- snapshot: nombre, foto, precio, rating, etc.

    -- Para hoteles: fechas de hospedaje como información visual (sin validación)
    hotel_checkin_date      DATE,           -- solo aplica si item_type = 'hotel'
    hotel_checkout_date     DATE,           -- solo aplica si item_type = 'hotel'

    -- Para vuelos: fecha/hora del vuelo (usada para auto-asignación al día correcto)
    flight_datetime         TIMESTAMP,      -- solo aplica si item_type IN ('flight_outbound','flight_return')

    start_time              TIME,
    end_time                TIME,
    order_position          SMALLINT NOT NULL DEFAULT 1,
    status                  VARCHAR(20) NOT NULL DEFAULT 'planned'
                                CHECK (status IN ('planned', 'confirmed', 'cancelled')),
    estimated_cost          DECIMAL(10, 2),
    created_at              TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMP NOT NULL DEFAULT NOW()
);

-- ============================================================
--  MÓDULO DE REFERENCIAS EXTERNAS
-- ============================================================

CREATE TABLE flight_references (
    reference_id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    external_flight_id  VARCHAR(255) NOT NULL,
    airline_code        VARCHAR(10),
    flight_number       VARCHAR(20),
    origin_airport      VARCHAR(10) NOT NULL,
    destination_airport VARCHAR(10) NOT NULL,
    departure_time      TIMESTAMP NOT NULL,
    arrival_time        TIMESTAMP NOT NULL,
    price               DECIMAL(10, 2),
    currency            VARCHAR(10) DEFAULT 'USD',
    api_source          VARCHAR(50) DEFAULT 'amadeus',
    cached_at           TIMESTAMP NOT NULL DEFAULT NOW(),
    cache_ttl_hours     SMALLINT DEFAULT 24
);

-- -------------------------------------------------------

CREATE TABLE hotel_references (
    reference_id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    external_place_id   VARCHAR(255) NOT NULL,          -- ID de Hotels4 / Agoda / etc.
    name                VARCHAR(255) NOT NULL,
    address             TEXT,
    latitude            DECIMAL(10, 7),
    longitude           DECIMAL(10, 7),
    checkin_date        DATE,
    checkout_date       DATE,
    price_per_night     DECIMAL(10, 2),
    currency            VARCHAR(10) DEFAULT 'USD',
    avg_rating          DECIMAL(3, 2),
    stars               SMALLINT CHECK (stars BETWEEN 1 AND 5),
    photo_reference     TEXT,
    api_source          VARCHAR(50),
    cached_at           TIMESTAMP NOT NULL DEFAULT NOW()
);

-- -------------------------------------------------------

CREATE TABLE restaurant_references (
    reference_id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    external_place_id   VARCHAR(255) NOT NULL,          -- Google Places ID
    name                VARCHAR(255) NOT NULL,
    address             TEXT,
    latitude            DECIMAL(10, 7),
    longitude           DECIMAL(10, 7),
    avg_rating          DECIMAL(3, 2),
    price_level         SMALLINT CHECK (price_level BETWEEN 1 AND 4),
    cuisine_types       JSONB,                          -- ["sushi", "japonesa"]
    photo_reference     TEXT,
    api_source          VARCHAR(50) DEFAULT 'google_places',
    cached_at           TIMESTAMP NOT NULL DEFAULT NOW()
);

-- -------------------------------------------------------

CREATE TABLE poi_references (
    reference_id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    external_place_id   VARCHAR(255) NOT NULL,
    name                VARCHAR(255) NOT NULL,
    category            VARCHAR(60),                    -- 'museum','monument','park','viewpoint'
    address             TEXT,
    latitude            DECIMAL(10, 7),
    longitude           DECIMAL(10, 7),
    avg_rating          DECIMAL(3, 2),
    opening_hours       JSONB,
    entry_fee           DECIMAL(10, 2),
    currency            VARCHAR(10),
    photo_reference     TEXT,
    cached_at           TIMESTAMP NOT NULL DEFAULT NOW()
);

-- -------------------------------------------------------

CREATE TABLE essential_service_references (
    reference_id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    external_place_id   VARCHAR(255) NOT NULL,
    service_type        VARCHAR(30) NOT NULL
                            CHECK (service_type IN ('restroom','hospital','pharmacy','police','atm')),
    name                VARCHAR(255),
    latitude            DECIMAL(10, 7) NOT NULL,
    longitude           DECIMAL(10, 7) NOT NULL,
    address             TEXT,
    is_free             BOOLEAN DEFAULT FALSE,
    accessibility_info  JSONB,
    cached_at           TIMESTAMP NOT NULL DEFAULT NOW()
);

-- ============================================================
--  MÓDULO DE NOTIFICACIONES
-- ============================================================

CREATE TABLE email_notifications (
    notification_id     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    notification_type   VARCHAR(40) NOT NULL
                            CHECK (notification_type IN (
                                'welcome',
                                'password_reset',
                                'draft_reminder',
                                'archive_warning',
                                'trip_upcoming',
                                'trip_confirmed'
                            )),
    subject             VARCHAR(255),
    template_data       JSONB,
    status              VARCHAR(20) NOT NULL DEFAULT 'pending'
                            CHECK (status IN ('pending','sent','failed','cancelled')),
    scheduled_for       TIMESTAMP,
    sent_at             TIMESTAMP,
    retry_count         SMALLINT DEFAULT 0,
    error_message       TEXT,
    related_entity_type VARCHAR(30),    -- 'trip' | 'user'
    related_entity_id   UUID,
    created_at          TIMESTAMP NOT NULL DEFAULT NOW()
);

