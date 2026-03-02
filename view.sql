
-- ------------------------------------------------------------
--  VIEW 1: Viajes favoritos del usuario
--  Uso: GET /api/trips?favorite=true
--  Retorna viajes marcados como favoritos con resumen de ítems
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW vw_favorite_trips AS
SELECT
    t.trip_id,
    t.user_id,
    t.trip_name,
    t.start_date,
    t.end_date,
    t.status,
    t.total_budget,
    t.currency,
    t.confirmed_at,
    t.created_at,
    t.updated_at,
    d.name           AS destination_name,
    d.country        AS destination_country,
    d.city           AS destination_city,
    d.image_url      AS destination_image,
    -- Cantidad de días del viaje
    (t.end_date - t.start_date + 1)                         AS total_days,
    -- Cantidad de ítems confirmados en el itinerario
    COUNT(ii.item_id)                                        AS total_items,
    -- Costo total acumulado de los ítems
    COALESCE(SUM(ii.estimated_cost), 0)                      AS accumulated_cost
FROM trips t
LEFT JOIN destinations d         ON d.destination_id = t.destination_id
LEFT JOIN itinerary_days id_days ON id_days.trip_id  = t.trip_id
LEFT JOIN itinerary_items ii     ON ii.day_id         = id_days.day_id
                                 AND ii.status        <> 'cancelled'
WHERE t.is_favorite = TRUE
GROUP BY
    t.trip_id, t.user_id, t.trip_name, t.start_date, t.end_date,
    t.status, t.total_budget, t.currency, t.confirmed_at,
    t.created_at, t.updated_at,
    d.name, d.country, d.city, d.image_url;


-- ------------------------------------------------------------
--  VIEW 2: Historial de viajes completados
--  Uso: GET /api/users/me/history
--  Retorna viajes en status 'completed' con info del destino
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW vw_travel_history AS
SELECT
    uth.history_id,
    uth.user_id,
    uth.trip_id,
    uth.destination,
    uth.country,
    uth.travel_date,
    uth.rating,
    uth.tags,
    uth.created_at,
    t.trip_name,
    t.start_date,
    t.end_date,
    t.currency,
    -- Costo total gastado en ese viaje
    COALESCE(SUM(ii.estimated_cost), 0) AS total_spent,
    -- Destino imagen si existe
    d.image_url                          AS destination_image
FROM user_travel_history uth
LEFT JOIN trips t            ON t.trip_id        = uth.trip_id
LEFT JOIN destinations d     ON d.destination_id = t.destination_id
LEFT JOIN itinerary_days idd ON idd.trip_id      = uth.trip_id
LEFT JOIN itinerary_items ii ON ii.day_id        = idd.day_id
                             AND ii.status       <> 'cancelled'
GROUP BY
    uth.history_id, uth.user_id, uth.trip_id, uth.destination,
    uth.country, uth.travel_date, uth.rating, uth.tags, uth.created_at,
    t.trip_name, t.start_date, t.end_date, t.currency,
    d.image_url;


-- ------------------------------------------------------------
--  VIEW 3: Wishlist con info del destino
--  Uso: GET /api/wishlist
--  Cruza la wishlist con destinations para enriquecer los datos
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW vw_wishlist AS
SELECT
    w.wishlist_id,
    w.user_id,
    w.country,
    w.city,
    w.created_at,
    d.destination_id,
    d.image_url          AS destination_image,
    d.latitude,
    d.longitude,
    d.timezone,
    d.currency_code,
    d.popular_months,
    -- Precio mínimo de vuelo más reciente disponible (cualquier origen)
    (
        SELECT MIN(fpt.min_price)
        FROM flight_price_trends fpt
        WHERE fpt.destination_id = d.destination_id
    )                    AS min_flight_price
FROM wishlist w
LEFT JOIN destinations d
       ON LOWER(d.country) = LOWER(w.country)
      AND LOWER(d.city)    = LOWER(w.city);
