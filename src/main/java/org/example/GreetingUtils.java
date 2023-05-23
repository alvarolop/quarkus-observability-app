package org.example;

import io.opentelemetry.api.trace.SpanKind;
import io.opentelemetry.instrumentation.annotations.WithSpan;
import io.quarkus.logging.Log;
import jakarta.enterprise.context.ApplicationScoped;

@ApplicationScoped
public class GreetingMethods {

    @WithSpan(value = "executeSubprocess", kind = SpanKind.SERVER)
    public void evaluate() {
        Log.info("Executing the subprocess");
        try {
            Thread.sleep(200L);
        } catch (InterruptedException e) {
            // TODO Auto-generated catch block
            e.printStackTrace();
        }
    }
}
