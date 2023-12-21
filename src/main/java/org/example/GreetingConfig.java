package org.example;

import io.smallrye.config.ConfigMapping;
import io.smallrye.config.WithDefault;
import io.smallrye.config.WithName;

@ConfigMapping(prefix = "app")
public interface GreetingConfig {

    @WithName("greeting.message")
    @WithDefault("Hello!")
    String message();

    @WithName("delay.default")
    @WithDefault("200")
    int defaultDelay();

}
