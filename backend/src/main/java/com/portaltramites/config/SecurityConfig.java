package com.portaltramites.config;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.portaltramites.error.ErrorResponse;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.access.AccessDeniedHandler;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

import java.io.IOException;
import java.time.LocalDateTime;
import java.util.List;

/**
 * Seguridad: sin autenticación (API pública de solo lectura), pero con CORS
 * restringido únicamente al origen del frontend (Vite: http://localhost:5173).
 * Los errores 401/403 se devuelven en el mismo formato JSON de ErrorResponse.
 */
@Configuration
@EnableWebSecurity
public class SecurityConfig {

    private static final String ORIGEN_FRONTEND = "http://localhost:5173";

    private final ObjectMapper objectMapper;

    public SecurityConfig(ObjectMapper objectMapper) {
        this.objectMapper = objectMapper;
    }

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
                .csrf(AbstractHttpConfigurer::disable)
                .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .cors(c -> c.configurationSource(corsConfigurationSource()))
                .authorizeHttpRequests(a -> a.anyRequest().permitAll())
                .exceptionHandling(e -> e
                        .authenticationEntryPoint(puntoEntradaNoAutenticado())
                        .accessDeniedHandler(manejadorAccesoDenegado()));
        return http.build();
    }

    /**
     * CORS: solo el frontend puede consumir la API desde el navegador.
     */
    @Bean
    public CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration config = new CorsConfiguration();
        config.setAllowedOrigins(List.of(ORIGEN_FRONTEND));
        config.setAllowedMethods(List.of("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"));
        config.setAllowedHeaders(List.of("*"));
        config.setAllowCredentials(false);
        config.setMaxAge(3600L);

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", config);
        return source;
    }

    /** 401: solicitud sin autenticación. */
    private AuthenticationEntryPoint puntoEntradaNoAutenticado() {
        return (HttpServletRequest req, HttpServletResponse res, AuthenticationException ex) ->
                escribir(res, HttpStatus.UNAUTHORIZED, "Autenticación requerida", req.getRequestURI());
    }

    /** 403: autenticado pero sin permisos. */
    private AccessDeniedHandler manejadorAccesoDenegado() {
        return (HttpServletRequest req, HttpServletResponse res, org.springframework.security.access.AccessDeniedException ex) ->
                escribir(res, HttpStatus.FORBIDDEN, "Acceso denegado", req.getRequestURI());
    }

    private void escribir(HttpServletResponse res, HttpStatus status, String mensaje, String ruta)
            throws IOException {
        res.setStatus(status.value());
        res.setContentType(MediaType.APPLICATION_JSON_VALUE);
        ErrorResponse body = new ErrorResponse(
                LocalDateTime.now(), status.value(), status.getReasonPhrase(), mensaje, ruta);
        objectMapper.writeValue(res.getOutputStream(), body);
    }
}
