package org.example;

import io.micrometer.core.annotation.Counted;
import io.micrometer.core.annotation.Timed;
import io.quarkus.logging.Log;
import jakarta.inject.Inject;
import jakarta.ws.rs.BadRequestException;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;

import org.jboss.resteasy.reactive.server.ServerExceptionMapper;
import org.jboss.resteasy.reactive.RestResponse;

@Path("/api/")
public class GreetingResource {

    @Inject
    GreetingConfig greetingConfig;

    @Inject
    GreetingUtils greetingUtils;

    //
    /* Hello Requests */
    //

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
        greetingUtils.wait(100);
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
        greetingUtils.wait(100);
        Log.info(greetingConfig.message());
        greetingUtils.evaluate(ms);
        return greetingConfig.message();
    }

    //
    /* Error Requests */
    //

    @ServerExceptionMapper
    public RestResponse<String> mapException(BadRequestException x) {
        return RestResponse.status(Response.Status.NOT_FOUND, "This is a generic error");
    }

    @GET
    @Path("/error")
    @Produces(MediaType.TEXT_PLAIN)
    @Timed(value = "app.error.timed", longTask = true)
    @Counted(value = "app.error.counter")
    public String error() {
        Log.info("This is an error request");
        throw new BadRequestException();
    }

    @GET
    @Path("/error-delayed")
    @Produces(MediaType.TEXT_PLAIN)
    @Timed(value = "app.error-delayed.timed", longTask = true)
    @Counted(value = "app.error-delayed.counter")
    public String errorDelayed() {
        greetingUtils.wait(100);
        Log.info("This is a delayed error request for " + greetingConfig.defaultDelay() + " ms");
        greetingUtils.evaluate(greetingConfig.defaultDelay());
        throw new BadRequestException();
    }

}
