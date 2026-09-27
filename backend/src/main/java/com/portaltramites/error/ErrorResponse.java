package com.portaltramites.error;

import java.time.LocalDateTime;

/**
 * Cuerpo JSON estándar para todas las respuestas de error HTTP.
 */
public record ErrorResponse(LocalDateTime timestamp,
                            int status,
                            String error,
                            String mensaje,
                            String ruta) {

    public static ErrorResponse of(int status, String error, String mensaje, String ruta) {
        return new ErrorResponse(LocalDateTime.now(), status, error, mensaje, ruta);
    }
}
