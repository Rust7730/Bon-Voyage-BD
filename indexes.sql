-- Usuarios
CREATE INDEX idx_users_email         ON users(email);
CREATE INDEX idx_users_google_id     ON users(google_id) WHERE google_id IS NOT NULL;
-- Wishlist
CREATE INDEX idx_wishlist_user       ON wishlist(user_id);
-- Viajes
CREATE INDEX idx_trips_user          ON trips(user_id);
CREATE INDEX idx_trips_status        ON trips(user_id, status);
CREATE INDEX idx_trips_favorites     ON trips(user_id, is_favorite) WHERE is_favorite = TRUE;
-- Días e ítems
CREATE INDEX idx_days_trip           ON itinerary_days(trip_id);
CREATE INDEX idx_items_day           ON itinerary_items(day_id);
CREATE INDEX idx_items_type          ON itinerary_items(item_type);
CREATE INDEX idx_items_flight_dt     ON itinerary_items(flight_datetime) 
                                     WHERE flight_datetime IS NOT NULL;
-- Notificaciones
CREATE INDEX idx_notifications_user   ON email_notifications(user_id);
CREATE INDEX idx_notifications_status ON email_notifications(status, scheduled_for)
                                      WHERE status = 'pending';
-- Destinos
CREATE INDEX idx_destinations_country ON destinations(country);