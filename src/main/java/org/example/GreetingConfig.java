package org.example;

import io.smallrye.config.ConfigMapping;
import io.smallrye.config.WithDefault;
import io.smallrye.config.WithName;

@ConfigMapping(prefix = "app.greeting")
public interface GreetingConfig {

    @WithName("message")
    @WithDefault("Hello!")
    String message();

}