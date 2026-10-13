package com.portaltramites.error;

public class DeepgramException extends RuntimeException {

    public DeepgramException(String mensaje) {
        super(mensaje);
    }

    public DeepgramException(String mensaje, Throwable causa) {
        super(mensaje, causa);
    }
}
