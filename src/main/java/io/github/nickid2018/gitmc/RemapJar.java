package io.github.nickid2018.gitmc;

import java.io.File;
import java.io.IOException;
import java.io.InputStreamReader;
import java.net.MalformedURLException;
import java.net.URI;
import java.net.URISyntaxException;
import java.net.URL;
import java.util.Locale;
import java.util.zip.ZipFile;

import org.apache.commons.io.IOUtils;

import com.google.gson.JsonObject;
import com.google.gson.JsonParser;

import io.github.nickid2018.mcde.FileProcessor;

public final class RemapJar {

    public static URL mirrorUrl (String url, boolean useMirror) throws URISyntaxException, MalformedURLException {
        URI newUri = new URI(url);
        newUri = new URI(newUri.getScheme().toLowerCase(Locale.US), "bmclapi2.bangbang93.com",
            newUri.getPath(), newUri.getQuery(), newUri.getFragment());
        return newUri.toURL();
    }
    public static void main(String[] args) throws IOException {
        if (args.length < 3) {
            System.exit(1);
        }

        String version = args[0];
        String url = args[1];
        String useMirror = args[2];

        try {
            System.out.println("Start remapping " + version);
            JsonObject versionData = JsonParser.parseReader(
                    new InputStreamReader(new URL(url).openStream())).getAsJsonObject();
            JsonObject downloads = versionData.getAsJsonObject("downloads");

            String clientURL = downloads.getAsJsonObject("client").get("url").getAsString();
            String mappingURL = downloads.getAsJsonObject("client_mappings").get("url").getAsString();

            IOUtils.copy(mirrorUrl(clientURL, "true".equals(useMirror)), new File("client.jar"));
            IOUtils.copy(mirrorUrl(mappingURL, "true".equals(useMirror)), new File("mapping.txt"));

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
