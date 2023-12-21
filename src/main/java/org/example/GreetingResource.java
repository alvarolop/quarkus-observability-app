package org.example;

import io.micrometer.core.annotation.Counted;
import io.micrometer.core.annotation.Timed;
import io.quarkus.logging.Log;
import jakarta.inject.Inject;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;

@Path("/api/")
public class GreetingResource {

    @Inject
    GreetingConfig greetingConfig;

    @Inject
    GreetingUtils greetingUtils;

    @GET
    @Path("/hello")
    @Produces(MediaType.TEXT_PLAIN)
    @Timed(value = "app.hello.timed", longTask = true)
    @Counted(value = "app.hello.counter")
    public String hello() {
        Log.info(greetingConfig.message());
        return greetingConfig.message();
    }

    @GET
    @Path("/hello-delayed")
    @Produces(MediaType.TEXT_PLAIN)
    @Timed(value = "app.hello-delayed.timed", longTask = true)
    @Counted(value = "app.hello-delayed.counter")
    public String helloDelayed() {
        Log.info(greetingConfig.message());
        greetingUtils.evaluate(greetingConfig.defaultDelay());
        return greetingConfig.message();
    }

    @GET
    @Path("/hello-delayed/{ms:\\d+}")
    @Produces(MediaType.TEXT_PLAIN)
    @Timed(value = "app.hello-delayed-ms.timed", longTask = true)
    @Counted(value = "app.hello-delayed-ms.counter")
    public String helloDelayedSeconds(int ms) {
        Log.info(greetingConfig.message());
        greetingUtils.evaluate(ms);
        return greetingConfig.message();
    }
}
