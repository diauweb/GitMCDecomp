package io.github.nickid2018.gitmc;

import java.io.File;
import java.io.IOException;
import java.io.InputStreamReader;
import java.net.URL;
import java.util.zip.ZipFile;

import org.apache.commons.io.IOUtils;

import com.google.gson.JsonObject;
import com.google.gson.JsonParser;

import io.github.nickid2018.mcde.FileProcessor;

public final class RemapJar {
    public static void main(String[] args) throws IOException {
        if (args.length < 0) {
            System.exit(1);
        }

        String version = args[0];
        String url = args[1];

        try {
            System.out.println("Start remapping " + version);
            JsonObject versionData = JsonParser.parseReader(
                    new InputStreamReader(new URL(url).openStream())).getAsJsonObject();
            JsonObject downloads = versionData.getAsJsonObject("downloads");

            String clientURL = downloads.getAsJsonObject("client").get("url").getAsString();
            String mappingURL = downloads.getAsJsonObject("client_mappings").get("url").getAsString();

            IOUtils.copy(new URL(clientURL), new File("client.jar"));
            IOUtils.copy(new URL(mappingURL), new File("mapping.txt"));

            try (ZipFile file = new ZipFile(new File("client.jar"))) {
                FileProcessor.process(file, new File("mapping.txt"), new File(String.format("remapped-%s.jar", version)));
            }
        } catch (Exception e) {
            System.out.println("Remap " + version + " failed");
            e.printStackTrace();
            System.exit(1);
        }
    }
}
