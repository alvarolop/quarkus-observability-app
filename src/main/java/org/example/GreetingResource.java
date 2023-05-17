package org.example;

import io.micrometer.core.annotation.Counted;
import io.micrometer.core.annotation.Timed;
import io.opentelemetry.api.trace.SpanKind;
import io.opentelemetry.instrumentation.annotations.WithSpan;
import io.quarkus.logging.Log;
import jakarta.inject.Inject;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;

@Path("/hello")
public class GreetingResource {

    @Inject
    GreetingConfig greetingConfig;

    @GET
    @Produces(MediaType.TEXT_PLAIN)
    @Timed(value = "app.hello.timed", longTask = true)
    @Counted(value = "app.hello.counter")
    public String hello() {
        Log.info(greetingConfig.message());
        executeSubprocess();
        return greetingConfig.message();
    }

    @WithSpan(value = "executeSubprocess", kind = SpanKind.SERVER)
    public void executeSubprocess() {
        Log.info("Executing the subprocess");
    }
}
