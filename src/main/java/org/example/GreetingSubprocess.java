package org.example;

import io.quarkus.logging.Log;

public class GreetingSubprocess {

    public String execute() {
        Log.info("Executing the subprocess");
        return "hi";
    }
}
